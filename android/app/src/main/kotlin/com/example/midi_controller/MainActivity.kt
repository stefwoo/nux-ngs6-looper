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

    private val usbPermissionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (USB_PERMISSION == intent.action) {
                synchronized(this) {
                    val device: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                        Log.d(TAG, "Permission granted for device ${device?.deviceName}")
                    } else {
                        Log.d(TAG, "Permission denied for device ${device?.deviceName}")
                    }
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(usbPermissionReceiver)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
            permissionIntent = PendingIntent.getBroadcast(
                this, 0, Intent(USB_PERMISSION), 
                PendingIntent.FLAG_IMMUTABLE
            )
            registerReceiver(usbPermissionReceiver, IntentFilter(USB_PERMISSION))
            Log.d(TAG, "USB components initialized successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize USB components", e)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getUsbDevices" -> {
                    if (!::usbManager.isInitialized) {
                        result.error("USB_NOT_INITIALIZED", "USB manager not initialized", null)
                        return@setMethodCallHandler
                    }
                    val deviceList = usbManager.deviceList.values.map { device ->
                        try {
                            usbManager.requestPermission(device, permissionIntent)
                            Log.d(TAG, "Requested permission for device: ${device.deviceName}")
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to request permission for device: ${device.deviceName}", e)
                        }
                        mapOf(
                            "deviceId" to device.deviceId,
                            "deviceName" to device.deviceName,
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
                        for (i in 0 until device.interfaceCount) {
                            val usbInterface = device.getInterface(i)
                            for (j in 0 until usbInterface.endpointCount) {
                                if (usbInterface.getEndpoint(j).direction == UsbConstants.USB_DIR_OUT) {
                                    midiInterface = usbInterface
                                    break
                                }
                            }
                            if (midiInterface != null) break
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
                        
                        val bytes = try {
                            message.split(" ").map { it.toInt(16).toByte() }.toByteArray()
                        } catch (e: Exception) {
                            result.error("INVALID_MESSAGE", "Invalid MIDI format", null)
                            return@setMethodCallHandler
                        }
                        
                        try {
                            val transferred = connection.bulkTransfer(outEndpoint, bytes, bytes.size, 1000)
                            if (transferred == bytes.size) {
                                result.success(true)
                            } else {
                                Log.e(TAG, "Transfer failed, expected ${bytes.size} bytes, transferred $transferred")
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
