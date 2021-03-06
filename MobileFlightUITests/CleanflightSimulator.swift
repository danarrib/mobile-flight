//
//  CleanflightSimulator.swift
//  Mobile Flight
//
//  Created by Raphael Jean-Leconte on 22/02/16.
//  Copyright © 2016 Raphael Jean-Leconte. All rights reserved.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import XCTest
@testable import MobileFlight

class CleanflightSimulator : NSObject, NSStreamDelegate {
    static let instance = CleanflightSimulator()
    
    let port = 8777
    
    private var mode: UInt32 = 0        // Flight modes
    var voltage = 0.0
    var amps = 0.0
    var mAh = 0
    var rssi = 0
    var roll = 0.0
    var pitch = 0.0
    var heading = 0
    var altitude = 0.0
    var variometer = 0.0
    var numSats = 0
    var speed = 0.0
    var distanceToHome = 0
    
    private var boxnames: [Mode] = [ .ANGLE, .ARM, .GTUNE, .BARO, .BEEPER, .BLACKBOX, .CALIB, .CAMSTAB, .CAMTRIG, .FAILSAFE, .GOVERNOR, .GPS_HOLD, .GPS_HOME, .GTUNE, .HEADADJ, .HEADFREE, .HORIZON, .LEDLOW, .LEDMAX, .LLIGHTS, .MAG, .OSD_SW, .PASSTHRU, .SERVO1, .SERVO2, .SERVO3, .SONAR, .TELEMETRY, .AIR ]
    
    private var thread: NSThread!

    private var socketFD: Int32!
    
    private var socketContext: CFSocketContext!
    private var serviceSocket: CFSocket!
    private var serviceRunLoopSource: CFRunLoopSource!
    
    private var inStream: NSInputStream!
    private var outStream: NSOutputStream!
    
    private var codec = MSPCodec()
    
    func start() -> Bool {
        codec.gcsMode = false
        
        socketFD = socket(AF_INET, SOCK_STREAM, 0)
        
        var yes: UInt32 = 1
        Foundation.setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(sizeofValue(yes)))
        
        var sin = sockaddr_in()
        sin.sin_family = sa_family_t(AF_INET)
        sin.sin_len = UInt8(sizeofValue(sin))
        sin.sin_port = in_port_t(port).bigEndian
        
        let bindError = withUnsafePointer(&sin) {
            Foundation.bind(socketFD, UnsafePointer($0), UInt32(sin.sin_len))
        }
        if bindError != 0 {
            NSLog("CleanflightSimulator: Bind error %d", bindError)
            return false
        }
        var addrLen = socklen_t(sizeofValue(sin))
        
        let socketError = withUnsafeMutablePointers(&sin, &addrLen) { (sinPtr, addrPtr) -> Int32 in
            getsockname(socketFD, UnsafeMutablePointer(sinPtr), UnsafeMutablePointer(addrPtr))
        }
        if socketError != 0 {
            NSLog("CleanflightSimulator: Socket error %d", socketError)
            return false
        }
        
        let listenError = listen(socketFD, 5)
        if listenError != 0 {
            NSLog("CleanflightSimulator: Listen error %d", listenError)
            return false
        }
        
        var context = CFSocketContext()
        socketContext = context
        
        serviceSocket = withUnsafeMutablePointer(&context) {
            CFSocketCreateWithNative(nil, socketFD, CFSocketCallBackType.AcceptCallBack.rawValue, CallbackListen, UnsafePointer<CFSocketContext>($0))
        }
        
        serviceRunLoopSource = CFSocketCreateRunLoopSource(nil, serviceSocket, 0)
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), serviceRunLoopSource, kCFRunLoopCommonModes)
        
        return true
    }
    
    func stop() {
        closeStreams()
        close(socketFD)
        resetValues()
    }
    
    func resetValues() {
        mode = 0
        voltage = 0.0
        amps = 0
        mAh = 0
        rssi = 0
        roll = 0.0
        pitch = 0.0
        heading = 0
        altitude = 0.0
        variometer = 0.0
        numSats = 0
        speed = 0.0
        distanceToHome = 0
    }
    
    func stream(stream: NSStream, handleEvent eventCode: NSStreamEvent) {
        switch eventCode {
        case NSStreamEvent.None:
            break
            
        case NSStreamEvent.OpenCompleted:
            //serial.delegate = self
            //serial.open()
            break
            
        case NSStreamEvent.HasBytesAvailable:
            if stream == inStream {
                var buffer = [UInt8](count: 4096, repeatedValue: 0)
                let len = inStream.read(&buffer, maxLength: buffer.count)
                if (len > 0) {
                    receiveData([UInt8](buffer.prefix(len)))
                }
                else if (len <= 0) {
                    if (len < 0) {
                        NSLog("CleanflightSimulator: Communication error")
                    }
                    //close()
                }
            }
            
        case NSStreamEvent.HasSpaceAvailable:
            // FIXME Let assume all write can proceed ... sendIfAvailable()
            break
            
        case NSStreamEvent.ErrorOccurred:
            NSLog("CleanflightSimulator: NSStreamEvent.ErrorOccurred")
            closeStreams()
            
        case NSStreamEvent.EndEncountered:
            NSLog("CleanflightSimulator: End of stream")
            closeStreams()
            
        default:
            break
        }
    }

    private func closeStreams() {
        thread.cancel()
    }

    private func receiveData(data: [UInt8]) {
        for b in data {
            if let (status, mspCode, message) = codec.decode(b) {
                if status {
                    operation(mspCode, message: message)
                }
            }
        }
    }
    
    private func short(v: Int) -> NSNumber {
        return NSNumber(short: Int16(v))
    }
    
    private func byte(v: Int) -> NSNumber {
        return NSNumber(char: Int8(v))
    }
    
    private func uint(v: Int) -> NSNumber {
        return NSNumber(unsignedInt: UInt32(v))
    }
    
    private func int(v: Int) -> NSNumber {
        return NSNumber(int: Int32(v))
    }
    
    private func operation(mspCode: MSP_code, message: [UInt8]) {
        NSLog("CleanflightSimulator: operation %d", mspCode.rawValue)
        switch mspCode {
        case .MSP_FC_VARIANT:
            send(mspCode, "CLFL")
        case .MSP_API_VERSION:
            send(mspCode, byte(0), byte(1), byte(16))
        case .MSP_ATTITUDE:
            send(mspCode, short(Int(roll * 10)), short(Int(pitch * 10)), short(heading))
        case .MSP_ALTITUDE:
            send(mspCode, int(Int(altitude * 100)), short(Int(variometer * 100)))
        case .MSP_UID:
            send(mspCode, uint(0xBAADF00D), uint(0xBAADF00D), uint(0xBAADF00D))
        case .MSP_BOXNAMES:
            var boxnamesString = ""
            for name in boxnames {
                boxnamesString += name.rawValue + ";"
            }
            send(mspCode, boxnamesString);
        case .MSP_STATUS, .MSP_STATUS_EX:
            send(mspCode, short(3500), short(0), short(0x7FFF), uint(Int(bitPattern: UInt(mode))), byte(0))
        case .MSP_ANALOG:
            send(mspCode, byte(Int(voltage * 10.0)), short(mAh), short(rssi), short(Int(amps * 100)))
        case .MSP_RAW_GPS:
            send(mspCode, byte(1), byte(numSats), int(0), int(0), short(0), short(Int(speed * 100000 / 3600)), short(heading * 10))
        case .MSP_COMP_GPS:
            send(mspCode, short(distanceToHome), short(0), byte(1))
        case .MSP_VOLTAGE_METER_CONFIG:
            send(mspCode, byte(110), byte(33), byte(43), byte(36))
        case .MSP_CURRENT_METER_CONFIG:
            send(mspCode, short(1), short(0), byte(1), short(1500))
        default:
            NSLog("CleanflightSimulator: Unhandled operation %d", mspCode.rawValue)
        }
    }
    
    private func send(mspCode: MSP_code, _ args: AnyObject...) {
        var message = [UInt8]()
        for n in args {
            if n is NSNumber {
                switch CFNumberGetType(n as! CFNumberRef) {
                case .SInt8Type:
                    message.append(n.unsignedCharValue);
                case .SInt16Type:
                    message.appendContentsOf(writeInt16(n.integerValue))
                    break
                case .SInt32Type, .SInt64Type:
                    message.appendContentsOf(writeInt32(n.integerValue))
                    break
                default:
                    XCTFail("Unsupported MSP message number argument type")
                }
            } else if n is String {
                message.appendContentsOf((n as! String).utf8)
            } else {
                XCTFail("Unsupported MSP message argument type")
            }
        }
        let data = codec.encode(mspCode, message: message)
        outStream.write(data, maxLength: data.count)
    }
    
    func startThread() {
        thread = NSThread(target: self, selector: "threadRun", object: nil)
        thread.start()
    }
    
    // Entry point of the background thread on which streams are scheduled
    func threadRun() {
        inStream.delegate = self
        outStream.delegate = self
        
        inStream.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)
        outStream.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)
        
        inStream.open()
        outStream.open()
        
        while true {
            NSRunLoop.currentRunLoop().runUntilDate(NSDate().dateByAddingTimeInterval(0.5))
            if NSThread.currentThread().cancelled {
                break
            }
        }
        
        inStream.close();
        outStream.close();
        inStream.removeFromRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)
        outStream.removeFromRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)
        inStream.delegate = nil
        outStream.delegate = nil
        inStream = nil
        outStream = nil
        NSLog("CleanflightSimulator: Communication closed")
    }

    func setMode(mode: Mode) {
        if let index = boxnames.indexOf(mode) {
            self.mode = self.mode | UInt32(1 << index)
        } else {
            XCTFail("Unknown mode")
        }
    }
    func unsetMode(mode: Mode) {
        if let index = boxnames.indexOf(mode) {
            self.mode = self.mode & ~UInt32(1 << index)
        } else {
            XCTFail("Unknown mode")
        }
    }
}


func CallbackListen(s: CFSocket!, callbackType: CFSocketCallBackType, address: CFData!, data: UnsafePointer<Void>, info: UnsafeMutablePointer<Void>) {
    NSLog("CleanflightSimulator: Incoming connection: \(data)")
    
    var readStream: Unmanaged<CFReadStream>?, writeStream: Unmanaged<CFWriteStream>?
    
    let nativeSocket = UnsafePointer<CFSocketNativeHandle>(data)
    
    CFStreamCreatePairWithSocket(kCFAllocatorDefault, nativeSocket.memory, &readStream, &writeStream)
    
    let server = CleanflightSimulator.instance
    
    server.inStream = readStream!.takeRetainedValue()
    server.outStream = writeStream!.takeRetainedValue()
    
    server.startThread()
}
