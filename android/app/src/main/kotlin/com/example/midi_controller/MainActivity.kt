package com.example.midi_controller

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbManager
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbConstants
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val TAG = "MidiController"
    private val CHANNEL = "com.example.midi_controller/usb"
    private val USB_PERMISSION = "com.example.midi_controller.USB_PERMISSION"
    private lateinit var usbManager: UsbManager
    private lateinit var permissionIntent: PendingIntent
    private lateinit var methodChannel: MethodChannel

    private val usbPermissionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (USB_PERMISSION == intent.action) {
                synchronized(this) {
                    val device: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                        Log.d(TAG, "Permission granted for device ${device?.deviceName}")
                        // 权限确认后自动刷新设备列表
                        refreshDeviceList()
                    } else {
                        Log.d(TAG, "Permission denied for device ${device?.deviceName}")
                    }
                }
            }
        }
    }

    // USB设备插拔监听器
    private val usbDeviceReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    val device: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    Log.d(TAG, "USB device attached: ${device?.deviceName}")
                    refreshDeviceList()
                }
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    val device: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    Log.d(TAG, "USB device detached: ${device?.deviceName}")
                    refreshDeviceList()
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(usbPermissionReceiver)
            unregisterReceiver(usbDeviceReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering receivers", e)
        }
    }

    /**
     * 获取设备友好名称
     */
    private fun getDeviceFriendlyName(device: UsbDevice): String {
        // 优先级：productName > manufacturerName > vendorId:productId
        device.productName?.let { 
            if (it.isNotBlank()) return it 
        }
        device.manufacturerName?.let { 
            if (it.isNotBlank()) return it 
        }
        return String.format("%04X:%04X", device.vendorId, device.productId)
    }

    /**
     * 刷新设备列表并通知Flutter端
     */
    private fun refreshDeviceList() {
        if (!::usbManager.isInitialized || !::methodChannel.isInitialized) {
            Log.w(TAG, "USB manager or method channel not initialized")
            return
        }

        try {
            val deviceList = usbManager.deviceList.values.map { device ->
                mapOf(
                    "deviceId" to device.deviceId,
                    "deviceName" to getDeviceFriendlyName(device),
                    "vendorId" to device.vendorId,
                    "productId" to device.productId,
                    "hasPermission" to usbManager.hasPermission(device)
                )
            }
            
            // 通知Flutter端设备列表已更新
            runOnUiThread {
                methodChannel.invokeMethod("onDeviceListUpdated", deviceList)
            }
            Log.d(TAG, "Device list refreshed, found ${deviceList.size} devices")
        } catch (e: Exception) {
            Log.e(TAG, "Error refreshing device list", e)
        }
    }

    /**
     * 将标准MIDI消息转换为USB MIDI包格式
     * USB MIDI使用4字节包格式：
     * 字节0: Cable Number (4位) + Code Index Number (4位)
     * 字节1-3: MIDI消息 (最多3字节)
     */
    private fun createUsbMidiPacket(midiBytes: ByteArray): ByteArray {
        if (midiBytes.isEmpty()) {
            return byteArrayOf()
        }

        val cableNumber = 0 // 通常使用cable 0
        val statusByte = midiBytes[0].toInt() and 0xFF
        
        // 根据MIDI消息类型确定Code Index Number
        val codeIndexNumber = when {
            // Note Off: 8x
            (statusByte and 0xF0) == 0x80 -> 0x8
            // Note On: 9x
            (statusByte and 0xF0) == 0x90 -> 0x9
            // Polyphonic Key Pressure: Ax
            (statusByte and 0xF0) == 0xA0 -> 0xA
            // Control Change: Bx
            (statusByte and 0xF0) == 0xB0 -> 0xB
            // Program Change: Cx
            (statusByte and 0xF0) == 0xC0 -> 0xC
            // Channel Pressure: Dx
            (statusByte and 0xF0) == 0xD0 -> 0xD
            // Pitch Bend: Ex
            (statusByte and 0xF0) == 0xE0 -> 0xE
            // System messages: Fx
            (statusByte and 0xF0) == 0xF0 -> when (statusByte) {
                0xF0 -> 0x4 // SysEx start
                0xF1 -> 0x2 // MTC Quarter Frame
                0xF2 -> 0x3 // Song Position Pointer
                0xF3 -> 0x2 // Song Select
                0xF6 -> 0x5 // Tune Request
                0xF7 -> 0x5 // SysEx end
                0xF8 -> 0xF // Timing Clock
                0xFA -> 0xF // Start
                0xFB -> 0xF // Continue
                0xFC -> 0xF // Stop
                0xFE -> 0xF // Active Sensing
                0xFF -> 0xF // Reset
                else -> 0xF
            }
            else -> 0x0
        }

        // 构建4字节USB MIDI包
        val packet = ByteArray(4)
        packet[0] = ((cableNumber shl 4) or codeIndexNumber).toByte()
        
        // 复制MIDI数据，不足3字节的用0填充
        for (i in 0 until minOf(3, midiBytes.size)) {
            packet[i + 1] = midiBytes[i]
        }
        
        return packet
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
            permissionIntent = PendingIntent.getBroadcast(
                this, 0, Intent(USB_PERMISSION), 
                PendingIntent.FLAG_IMMUTABLE
            )
            
            // 注册权限接收器
            registerReceiver(usbPermissionReceiver, IntentFilter(USB_PERMISSION))
            
            // 注册USB设备插拔监听器
            val usbFilter = IntentFilter().apply {
                addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
                addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
            }
            registerReceiver(usbDeviceReceiver, usbFilter)
            
            Log.d(TAG, "USB components initialized successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize USB components", e)
        }

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getUsbDevices" -> {
                    if (!::usbManager.isInitialized) {
                        result.error("USB_NOT_INITIALIZED", "USB manager not initialized", null)
                        return@setMethodCallHandler
                    }
                    val deviceList = usbManager.deviceList.values.map { device ->
                        try {
                            usbManager.requestPermission(device, permissionIntent)
                            Log.d(TAG, "Requested permission for device: ${getDeviceFriendlyName(device)}")
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to request permission for device: ${getDeviceFriendlyName(device)}", e)
                        }
                        mapOf(
                            "deviceId" to device.deviceId,
                            "deviceName" to getDeviceFriendlyName(device),
                            "vendorId" to device.vendorId,
                            "productId" to device.productId,
                            "hasPermission" to usbManager.hasPermission(device)
                        )
                    }
                    result.success(deviceList)
                }
                "sendMidiMessage" -> {
                    val deviceId = call.argument<Int>("deviceId")
                    val message = call.argument<String>("message")
                    
                    if (deviceId == null || message == null) {
                        result.error("INVALID_ARGUMENTS", "Device ID or message is null", null)
                        return@setMethodCallHandler
                    }

                    val device = usbManager.deviceList.values.find { it.deviceId == deviceId }
                    if (device == null) {
                        result.error("DEVICE_NOT_FOUND", "USB device not found", null)
                        return@setMethodCallHandler
                    }

                    if (!usbManager.hasPermission(device)) {
                        result.error("PERMISSION_DENIED", "No permission to access USB device", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val connection = usbManager.openDevice(device)
                        if (connection == null) {
                            result.error("CONNECTION_FAILED", "Failed to open USB device", null)
                            return@setMethodCallHandler
                        }

                        var midiInterface: UsbInterface? = null
                        var fallbackInterface: UsbInterface? = null
                        
                        for (i in 0 until device.interfaceCount) {
                            val usbInterface = device.getInterface(i)
                            Log.d(TAG, "Interface $i: class=${usbInterface.interfaceClass}, subclass=${usbInterface.interfaceSubclass}, protocol=${usbInterface.interfaceProtocol}")
                            
                            // 首先检查标准MIDI接口 (Audio class, MIDI Streaming subclass)
                            if (usbInterface.interfaceClass == UsbConstants.USB_CLASS_AUDIO && 
                                usbInterface.interfaceSubclass == 3) {
                                Log.d(TAG, "Found standard MIDI interface: $i")
                                for (j in 0 until usbInterface.endpointCount) {
                                    val endpoint = usbInterface.getEndpoint(j)
                                    Log.d(TAG, "Endpoint $j: direction=${endpoint.direction}, type=${endpoint.type}")
                                    if (endpoint.direction == UsbConstants.USB_DIR_OUT) {
                                        midiInterface = usbInterface
                                        Log.d(TAG, "Found MIDI output endpoint in interface $i, endpoint $j")
                                        break
                                    }
                                }
                            }
                            // 如果没找到标准MIDI接口，记录有输出端点的接口作为fallback
                            else if (fallbackInterface == null) {
                                for (j in 0 until usbInterface.endpointCount) {
                                    val endpoint = usbInterface.getEndpoint(j)
                                    if (endpoint.direction == UsbConstants.USB_DIR_OUT) {
                                        fallbackInterface = usbInterface
                                        Log.d(TAG, "Found fallback interface with output endpoint: $i")
                                        break
                                    }
                                }
                            }
                            if (midiInterface != null) break
                        }
                        
                        // 如果没找到标准MIDI接口，尝试使用fallback接口
                        if (midiInterface == null && fallbackInterface != null) {
                            midiInterface = fallbackInterface
                            Log.d(TAG, "Using fallback interface for MIDI communication")
                        }

                        if (midiInterface == null) {
                            result.error("MIDI_INTERFACE_NOT_FOUND", "MIDI interface not found", null)
                            return@setMethodCallHandler
                        }

                        if (!connection.claimInterface(midiInterface, true)) {
                            result.error("INTERFACE_CLAIM_FAILED", "Failed to claim interface", null)
                            return@setMethodCallHandler
                        }

                        var outEndpoint: UsbEndpoint? = null
                        for (i in 0 until midiInterface.endpointCount) {
                            val ep = midiInterface.getEndpoint(i)
                            if (ep.direction == UsbConstants.USB_DIR_OUT) {
                                outEndpoint = ep
                                break
                            }
                        }

                        if (outEndpoint == null) {
                            result.error("MIDI_OUT_ENDPOINT_NOT_FOUND", "MIDI output endpoint not found", null)
                            return@setMethodCallHandler
                        }
                        
                        val midiBytes = try {
                            message.split(" ").map { it.toInt(16).toByte() }.toByteArray()
                        } catch (e: Exception) {
                            result.error("INVALID_MESSAGE", "Invalid MIDI format", null)
                            return@setMethodCallHandler
                        }
                        
                        Log.d(TAG, "Original MIDI message: $message")
                        Log.d(TAG, "MIDI bytes: ${midiBytes.joinToString(" ") { "%02X".format(it) }}")
                        
                        // 转换成USB MIDI包格式 (4字节)
                        val usbMidiPacket = createUsbMidiPacket(midiBytes)
                        Log.d(TAG, "USB MIDI packet: ${usbMidiPacket.joinToString(" ") { "%02X".format(it) }}")
                        
                        try {
                            val transferred = connection.bulkTransfer(outEndpoint, usbMidiPacket, usbMidiPacket.size, 1000)
                            Log.d(TAG, "Transfer result: $transferred bytes sent, expected ${usbMidiPacket.size}")
                            if (transferred == usbMidiPacket.size) {
                                result.success(true)
                            } else {
                                Log.e(TAG, "Transfer failed, expected ${usbMidiPacket.size} bytes, transferred $transferred")
                                result.error("TRANSFER_FAILED", "Failed to send MIDI", null)
                            }
                        } finally {
                            try {
                                connection.releaseInterface(midiInterface)
                            } catch (e: Exception) {
                                Log.e(TAG, "Error releasing interface", e)
                            }
                            try {
                                connection.close()
                            } catch (e: Exception) {
                                Log.e(TAG, "Error closing connection", e)
                            }
                        }
                    } catch (e: Exception) {
                        result.error("EXCEPTION", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
