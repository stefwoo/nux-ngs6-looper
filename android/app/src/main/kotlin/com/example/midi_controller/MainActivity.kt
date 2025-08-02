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
    
    // MIDI连接管理 - 统一的连接用于发送和接收
    private var midiConnection: UsbDeviceConnection? = null
    private var midiInEndpoint: UsbEndpoint? = null
    private var midiOutEndpoint: UsbEndpoint? = null
    private var midiInInterface: UsbInterface? = null
    private var midiOutInterface: UsbInterface? = null
    private var midiListeningThread: Thread? = null
    private var isListening = false
    private var currentDeviceId: Int? = null

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
        stopMidiListening()
        try {
            unregisterReceiver(usbPermissionReceiver)
            unregisterReceiver(usbDeviceReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering receivers", e)
        }
    }

    /**
     * 停止MIDI连接
     */
    private fun stopMidiConnection() {
        isListening = false
        midiListeningThread?.interrupt()
        midiListeningThread = null
        
        try {
            midiInInterface?.let { midiConnection?.releaseInterface(it) }
            midiOutInterface?.let { 
                if (it != midiInInterface) midiConnection?.releaseInterface(it) 
            }
            midiConnection?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping MIDI connection", e)
        }
        
        midiConnection = null
        midiInEndpoint = null
        midiOutEndpoint = null
        midiInInterface = null
        midiOutInterface = null
        currentDeviceId = null
        Log.d(TAG, "MIDI connection stopped")
    }

    /**
     * 停止MIDI监听（保持兼容性）
     */
    private fun stopMidiListening() {
        stopMidiConnection()
    }

    /**
     * 建立持久MIDI连接（用于发送和接收）
     */
    private fun establishMidiConnection(deviceId: Int): Boolean {
        Log.d(TAG, "🔗 Establishing MIDI connection for device $deviceId")
        
        try {
            // 如果已经连接到同一设备，不需要重新连接
            if (currentDeviceId == deviceId && midiConnection != null) {
                Log.d(TAG, "✅ Already connected to device $deviceId")
                Log.d(TAG, "🔍 Current connection status - Input: ${midiInEndpoint != null}, Output: ${midiOutEndpoint != null}")
                return true
            }
            
            // 先停止之前的连接
            Log.d(TAG, "🔄 Stopping previous connections...")
            stopMidiConnection()
            
            val device = usbManager.deviceList.values.find { it.deviceId == deviceId }
            if (device == null) {
                Log.e(TAG, "❌ Device not found: $deviceId")
                return false
            }

            Log.d(TAG, "📱 Device info: ${getDeviceFriendlyName(device)} (VID:${String.format("%04X", device.vendorId)} PID:${String.format("%04X", device.productId)})")

            if (!usbManager.hasPermission(device)) {
                Log.e(TAG, "❌ No permission for device $deviceId")
                return false
            }

            Log.d(TAG, "🔓 Opening device connection...")
            val connection = usbManager.openDevice(device)
            if (connection == null) {
                Log.e(TAG, "❌ Failed to open device $deviceId")
                return false
            }

            Log.d(TAG, "🔍 Scanning device interfaces (total: ${device.interfaceCount})...")
            
            // 寻找MIDI输入和输出接口及端点
            var inputInterface: UsbInterface? = null
            var inputEndpoint: UsbEndpoint? = null
            var outputInterface: UsbInterface? = null
            var outputEndpoint: UsbEndpoint? = null

            for (i in 0 until device.interfaceCount) {
                val usbInterface = device.getInterface(i)
                Log.d(TAG, "🔍 Interface $i: class=${usbInterface.interfaceClass}, subclass=${usbInterface.interfaceSubclass}, protocol=${usbInterface.interfaceProtocol}, endpoints=${usbInterface.endpointCount}")
                
                // 检查是否为音频类设备
                val isAudioClass = usbInterface.interfaceClass == UsbConstants.USB_CLASS_AUDIO
                val isMidiStreaming = usbInterface.interfaceSubclass == 3
                Log.d(TAG, "   📊 Audio class: $isAudioClass, MIDI streaming: $isMidiStreaming")
                
                // 检查端点
                for (j in 0 until usbInterface.endpointCount) {
                    val endpoint = usbInterface.getEndpoint(j)
                    val directionStr = if (endpoint.direction == UsbConstants.USB_DIR_IN) "IN" else "OUT"
                    val typeStr = when (endpoint.type) {
                        UsbConstants.USB_ENDPOINT_XFER_BULK -> "BULK"
                        UsbConstants.USB_ENDPOINT_XFER_INT -> "INTERRUPT"
                        UsbConstants.USB_ENDPOINT_XFER_ISOC -> "ISOCHRONOUS"
                        UsbConstants.USB_ENDPOINT_XFER_CONTROL -> "CONTROL"
                        else -> "UNKNOWN"
                    }
                    Log.d(TAG, "   🔌 Endpoint $j: direction=$directionStr, type=$typeStr, address=${String.format("0x%02X", endpoint.address)}")
                    
                    if (endpoint.direction == UsbConstants.USB_DIR_IN && inputInterface == null) {
                        inputInterface = usbInterface
                        inputEndpoint = endpoint
                        Log.d(TAG, "   ✅ Found MIDI INPUT endpoint in interface $i, endpoint $j")
                        Log.d(TAG, "   📋 Input endpoint details: address=${String.format("0x%02X", endpoint.address)}, maxPacketSize=${endpoint.maxPacketSize}")
                    } else if (endpoint.direction == UsbConstants.USB_DIR_OUT && outputInterface == null) {
                        outputInterface = usbInterface
                        outputEndpoint = endpoint
                        Log.d(TAG, "   ✅ Found MIDI OUTPUT endpoint in interface $i, endpoint $j")
                        Log.d(TAG, "   📋 Output endpoint details: address=${String.format("0x%02X", endpoint.address)}, maxPacketSize=${endpoint.maxPacketSize}")
                    }
                }
            }

            Log.d(TAG, "🔍 Interface discovery completed:")
            Log.d(TAG, "   📥 Input interface found: ${inputInterface != null}")
            Log.d(TAG, "   📤 Output interface found: ${outputInterface != null}")
            Log.d(TAG, "   🔗 Same interface: ${inputInterface == outputInterface}")

            if (outputInterface == null || outputEndpoint == null) {
                Log.e(TAG, "❌ MIDI output interface or endpoint not found")
                connection.close()
                return false
            }

            // 声明输出接口（必需）
            Log.d(TAG, "🔒 Claiming output interface (force=true)...")
            if (!connection.claimInterface(outputInterface, true)) {
                Log.e(TAG, "❌ Failed to claim output interface")
                connection.close()
                return false
            }
            Log.d(TAG, "✅ Output interface claimed successfully")

            // 声明输入接口（如果存在且与输出接口不同）
            if (inputInterface != null) {
                if (inputInterface != outputInterface) {
                    Log.d(TAG, "🔒 Claiming separate input interface (force=false)...")
                    if (!connection.claimInterface(inputInterface, false)) {
                        Log.w(TAG, "⚠️ Failed to claim input interface non-exclusively, trying force claim")
                        if (!connection.claimInterface(inputInterface, true)) {
                            Log.w(TAG, "❌ Failed to claim input interface, input disabled")
                            inputInterface = null
                            inputEndpoint = null
                        } else {
                            Log.d(TAG, "✅ Input interface claimed with force=true")
                        }
                    } else {
                        Log.d(TAG, "✅ Input interface claimed non-exclusively")
                    }
                } else {
                    Log.d(TAG, "ℹ️ Input and output use same interface - already claimed")
                }
            } else {
                Log.w(TAG, "⚠️ No input interface found - listening will be disabled")
            }

            // 保存连接信息
            midiConnection = connection
            midiInInterface = inputInterface
            midiOutInterface = outputInterface
            midiInEndpoint = inputEndpoint
            midiOutEndpoint = outputEndpoint
            currentDeviceId = deviceId

            Log.d(TAG, "✅ MIDI connection established for device $deviceId")
            Log.d(TAG, "📊 Final status:")
            Log.d(TAG, "   📥 Input available: ${inputInterface != null}")
            Log.d(TAG, "   📤 Output available: ${outputInterface != null}")
            Log.d(TAG, "   🔗 Connection object: ${connection != null}")
            
            return true

        } catch (e: Exception) {
            Log.e(TAG, "💥 Error establishing MIDI connection", e)
            return false
        }
    }

    /**
     * 开始MIDI监听
     */
    private fun startMidiListening(deviceId: Int): Boolean {
        try {
            // 先建立连接
            if (!establishMidiConnection(deviceId)) {
                return false
            }

            // 检查是否有输入端点
            if (midiInEndpoint == null) {
                Log.w(TAG, "No input endpoint available for listening")
                return false
            }

            isListening = true

            // 启动监听线程
            midiListeningThread = Thread {
                listenForMidiMessages()
            }
            midiListeningThread?.start()

            Log.d(TAG, "MIDI listening started for device $deviceId")
            return true

        } catch (e: Exception) {
            Log.e(TAG, "Error starting MIDI listening", e)
            return false
        }
    }

    /**
     * 监听MIDI消息的主循环
     */
    private fun listenForMidiMessages() {
        Log.d(TAG, "🎧 MIDI listening thread started")
        Log.d(TAG, "🔍 Thread ID: ${Thread.currentThread().id}, Name: ${Thread.currentThread().name}")
        Log.d(TAG, "🔍 Initial isListening: $isListening")
        Log.d(TAG, "🔍 Connection available: ${midiConnection != null}")
        Log.d(TAG, "🔍 Input endpoint available: ${midiInEndpoint != null}")
        
        val buffer = ByteArray(64) // USB MIDI包通常是4字节，但分配更大的缓冲区以防万一
        var loopCount = 0
        var lastLogTime = System.currentTimeMillis()
        
        while (isListening && !Thread.currentThread().isInterrupted()) {
            loopCount++
            val currentTime = System.currentTimeMillis()
            
            // 每5秒输出一次心跳日志
            if (currentTime - lastLogTime >= 5000) {
                Log.d(TAG, "🔄 MIDI listening heartbeat - Loop count: $loopCount, isListening: $isListening")
                Log.d(TAG, "🔍 Connection status: ${midiConnection != null}, Endpoint status: ${midiInEndpoint != null}")
                lastLogTime = currentTime
            }
            
            try {
                val connection = midiConnection
                if (connection == null) {
                    Log.e(TAG, "❌ Connection lost during listening")
                    break
                }
                val endpoint = midiInEndpoint
                if (endpoint == null) {
                    Log.e(TAG, "❌ Input endpoint lost during listening")
                    break
                }
                
                // 增加详细的bulkTransfer调试
                val startTime = System.currentTimeMillis()
                val bytesRead = connection.bulkTransfer(endpoint, buffer, buffer.size, 100) // 100ms超时
                val transferTime = System.currentTimeMillis() - startTime
                
                // 记录所有bulkTransfer调用结果，包括0字节的
                if (loopCount <= 10 || bytesRead > 0 || transferTime > 50) {
                    Log.d(TAG, "📡 bulkTransfer result: $bytesRead bytes, time: ${transferTime}ms, loop: $loopCount")
                }
                
                if (bytesRead > 0) {
                    Log.d(TAG, "🎵 Received $bytesRead bytes of MIDI data!")
                    Log.d(TAG, "📊 Raw buffer: ${buffer.take(bytesRead).joinToString(" ") { "%02X".format(it) }}")
                    
                    // 解析USB MIDI包
                    for (i in 0 until bytesRead step 4) {
                        if (i + 3 < bytesRead) {
                            val packet = buffer.sliceArray(i until i + 4)
                            Log.d(TAG, "📦 Processing packet $i: ${packet.joinToString(" ") { "%02X".format(it) }}")
                            
                            val midiMessage = parseUsbMidiPacket(packet)
                            if (midiMessage.isNotEmpty()) {
                                // 转换为十六进制字符串格式
                                val messageString = midiMessage.joinToString(" ") { "%02X".format(it) }
                                Log.d(TAG, "✅ Parsed MIDI message: $messageString")
                                Log.d(TAG, "📤 Sending to Flutter: $messageString")
                                
                                // 通知Flutter端
                                runOnUiThread {
                                    if (::methodChannel.isInitialized) {
                                        methodChannel.invokeMethod("onMidiMessageReceived", messageString)
                                        Log.d(TAG, "✅ Message sent to Flutter successfully")
                                    } else {
                                        Log.e(TAG, "❌ Method channel not initialized")
                                    }
                                }
                            } else {
                                Log.w(TAG, "⚠️ Packet parsed to empty MIDI message: ${packet.joinToString(" ") { "%02X".format(it) }}")
                            }
                        } else {
                            Log.w(TAG, "⚠️ Incomplete packet at position $i, total bytes: $bytesRead")
                        }
                    }
                } else if (bytesRead < 0) {
                    Log.w(TAG, "⚠️ bulkTransfer returned error: $bytesRead")
                }
            } catch (e: Exception) {
                if (isListening) {
                    Log.e(TAG, "💥 Error in MIDI listening loop (loop $loopCount)", e)
                }
                break
            }
        }
        Log.d(TAG, "🛑 MIDI listening loop ended - Final loop count: $loopCount")
        Log.d(TAG, "🔍 Final state - isListening: $isListening, interrupted: ${Thread.currentThread().isInterrupted()}")
    }

    /**
     * 解析USB MIDI包，提取MIDI消息
     */
    private fun parseUsbMidiPacket(packet: ByteArray): ByteArray {
        if (packet.size < 4) return byteArrayOf()
        
        val cableAndCode = packet[0].toInt() and 0xFF
        val cableNumber = (cableAndCode shr 4) and 0x0F // 提取Cable Number
        val codeIndexNumber = cableAndCode and 0x0F
        
        // 记录Cable Number信息用于调试
        Log.d(TAG, "📦 Parsing packet: cable=$cableNumber, code=$codeIndexNumber")
        
        // 接受来自Cable 2的输入（基于PC测试结果）
        if (cableNumber != 2) {
            Log.d(TAG, "⚠️ Ignoring packet from cable $cableNumber (expecting cable 2)")
            return byteArrayOf()
        }
        
        // 根据Code Index Number确定MIDI消息长度
        val midiLength = when (codeIndexNumber) {
            0x8, 0x9, 0xA, 0xB, 0xE -> 3 // Note On/Off, CC, Pitch Bend等3字节消息
            0xC, 0xD -> 2 // Program Change, Channel Pressure等2字节消息
            0xF -> when (packet[1].toInt() and 0xFF) {
                0xF0 -> 3 // SysEx start (可能需要更复杂处理)
                0xF1, 0xF3 -> 2 // MTC Quarter Frame, Song Select
                0xF2 -> 3 // Song Position Pointer
                0xF6, 0xF8, 0xFA, 0xFB, 0xFC, 0xFE, 0xFF -> 1 // 系统实时消息
                else -> 1
            }
            0x2, 0x3 -> 3 // 其他3字节消息
            0x4, 0x5, 0x6, 0x7 -> 3 // SysEx相关
            else -> 0
        }
        
        if (midiLength == 0) return byteArrayOf()
        
        // 提取MIDI数据字节（跳过第一个USB头字节）
        return packet.sliceArray(1 until minOf(4, 1 + midiLength))
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
                        hashMapOf<String, Any>(
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
    private fun createUsbMidiPacket(midiBytes: ByteArray, cableNumber: Int = 1): ByteArray {
        if (midiBytes.isEmpty()) {
            return byteArrayOf()
        }

        // 使用cable 1作为输出端口（基于PC测试结果）
        val actualCableNumber = cableNumber and 0x0F // 确保只用4位
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
        packet[0] = ((actualCableNumber shl 4) or codeIndexNumber).toByte()
        
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
                        hashMapOf<String, Any>(
                            "deviceId" to device.deviceId,
                            "deviceName" to getDeviceFriendlyName(device),
                            "vendorId" to device.vendorId,
                            "productId" to device.productId,
                            "hasPermission" to usbManager.hasPermission(device)
                        )
                    }
                    result.success(deviceList)
                }
                "requestUsbPermission" -> {
                    val deviceId = call.argument<Int>("deviceId")
                    if (deviceId == null) {
                        result.error("INVALID_ARGUMENTS", "Device ID is null", null)
                        return@setMethodCallHandler
                    }
                    
                    if (!::usbManager.isInitialized) {
                        result.error("USB_NOT_INITIALIZED", "USB manager not initialized", null)
                        return@setMethodCallHandler
                    }
                    
                    val device = usbManager.deviceList.values.find { it.deviceId == deviceId }
                    if (device == null) {
                        result.error("DEVICE_NOT_FOUND", "USB device not found", null)
                        return@setMethodCallHandler
                    }
                    
                    if (usbManager.hasPermission(device)) {
                        result.success(true)
                        return@setMethodCallHandler
                    }
                    
                    try {
                        usbManager.requestPermission(device, permissionIntent)
                        Log.d(TAG, "Requested permission for device: ${getDeviceFriendlyName(device)}")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to request permission for device: ${getDeviceFriendlyName(device)}", e)
                        result.error("PERMISSION_REQUEST_FAILED", e.message, null)
                    }
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

                    // 记录当前是否在监听状态
                    val wasListening = isListening
                    val savedDeviceId = currentDeviceId

                    try {
                        // 如果正在监听，先临时停止监听以释放接口资源
                        if (wasListening) {
                            Log.d(TAG, "Temporarily stopping listening for MIDI send")
                            stopMidiConnection()
                        }

                        // 使用独立连接发送MIDI消息
                        val connection = usbManager.openDevice(device)
                        if (connection == null) {
                            result.error("CONNECTION_FAILED", "Failed to open device for sending", null)
                            return@setMethodCallHandler
                        }

                        var midiInterface: UsbInterface? = null
                        var fallbackInterface: UsbInterface? = null
                        
                        for (i in 0 until device.interfaceCount) {
                            val usbInterface = device.getInterface(i)
                            
                            // 首先检查标准MIDI接口 (Audio class, MIDI Streaming subclass)
                            if (usbInterface.interfaceClass == UsbConstants.USB_CLASS_AUDIO && 
                                usbInterface.interfaceSubclass == 3) {
                                Log.d(TAG, "Found standard MIDI interface: $i")
                                for (j in 0 until usbInterface.endpointCount) {
                                    val endpoint = usbInterface.getEndpoint(j)
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
                            connection.close()
                            result.error("MIDI_INTERFACE_NOT_FOUND", "MIDI interface not found", null)
                            return@setMethodCallHandler
                        }

                        if (!connection.claimInterface(midiInterface, true)) {
                            connection.close()
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
                            connection.releaseInterface(midiInterface)
                            connection.close()
                            result.error("MIDI_OUT_ENDPOINT_NOT_FOUND", "MIDI output endpoint not found", null)
                            return@setMethodCallHandler
                        }
                        
                        val midiBytes = try {
                            message.split(" ").map { it.toInt(16).toByte() }.toByteArray()
                        } catch (e: Exception) {
                            connection.releaseInterface(midiInterface)
                            connection.close()
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
                            // 确保释放发送连接资源
                            try {
                                connection.releaseInterface(midiInterface)
                                connection.close()
                                Log.d(TAG, "Send connection closed")
                            } catch (e: Exception) {
                                Log.e(TAG, "Error closing send connection", e)
                            }
                        }
                        
                    } catch (e: Exception) {
                        Log.e(TAG, "Error sending MIDI message", e)
                        result.error("EXCEPTION", e.message, null)
                    } finally {
                        // 如果之前在监听，立即恢复监听状态
                        if (wasListening && savedDeviceId != null) {
                            Log.d(TAG, "Restoring listening after MIDI send")
                            startMidiListening(savedDeviceId)
                        }
                    }
                }
                "startMidiListening" -> {
                    val deviceId = call.argument<Int>("deviceId")
                    if (deviceId == null) {
                        result.error("INVALID_ARGUMENTS", "Device ID is null", null)
                        return@setMethodCallHandler
                    }
                    
                    val success = startMidiListening(deviceId)
                    result.success(success)
                }
                "stopMidiListening" -> {
                    stopMidiListening()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
