//
//  ViewController.swift
//  screen_com
//
//  Created by Andrew Wagenmaker on 5/22/20.
//  Copyright © 2020 Andrew Wagenmaker. All rights reserved.
//

import UIKit
import AVFoundation





class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet weak var gestureView: GestureView!

    var videoCaptureOutput = AVCaptureVideoDataOutput()

    private let dataOutputQueue = DispatchQueue(label: "VideoDataQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)

    let captureSession = AVCaptureSession()
    
    var count: Double = 0.0
    var start_time: Double = 0.0
    
    var idx = 0
    let fft_size = 16
    var color_ints: Array<Float> = Array(repeating: 0.0, count: 16)
    var candidate_bits: Array<Int> = Array(repeating: 0, count: 100)
    var bits: Array<Int> = Array(repeating: 0, count: 100)
    var idx_bits = 0
    var idx_cand = 0
    var last16: Array<Int> = Array(repeating: 0, count: 16)
    var idx_last16 = 0
    let start_sequence = [1,1,1,1,0,0,0,0]
    var start_idx = -1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        captureSession.beginConfiguration()
       
        var discover = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)

        let videoDevice = discover.devices[0]
        do {
            try videoDevice.lockForConfiguration()
            videoDevice.activeFormat = videoDevice.formats[0]
            videoDevice.exposureMode = .locked
            try videoDevice.unlockForConfiguration()
            videoDevice.set(frameRate: 30.0)
        } catch {
            print(error)
        }
        guard
            let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
            captureSession.canAddInput(videoDeviceInput)
            else { return }
        captureSession.addInput(videoDeviceInput)

        // Add a video data output
        if captureSession.canAddOutput(videoCaptureOutput) {
            captureSession.addOutput(videoCaptureOutput)
            videoCaptureOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            videoCaptureOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        } else {
            print("Could not add video data output to the session")
            return
        }
        captureSession.commitConfiguration()

        captureSession.startRunning()
        start_time = Double(NSDate().timeIntervalSince1970 * 1000)
    }

    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let im = imageFromSampleBuffer(sampleBuffer: sampleBuffer)
        let im2 = resizeImage(image: im, newWidth: 10.0)
        let im_data = im2.pixelData()
       
        var avg_r: Float = 0.0
        var avg_g: Float = 0.0
        var avg_b: Float = 0.0
        let total_pixels: Float = 240.0 / 4.0

        for i in 0...(240-1) {
            if i % 4 == 0 {
                avg_r += Float(im_data![i]) / total_pixels
            } else if i % 4 == 1 {
                avg_g += Float(im_data![i]) / total_pixels
            } else if i % 4 == 2 {
                avg_b += Float(im_data![i]) / total_pixels
            }
        }
        
        let color_intensity = sqrt(avg_r*avg_r + avg_g*avg_g + avg_b*avg_b)
        color_ints[idx] = color_intensity
        idx += 1
        if idx >= self.fft_size {
            idx = 0
        }
        
        var fft = TempiFFT(withSize: self.fft_size, sampleRate: 30.0)
        fft.fftForward(color_ints)
        var mags = fft.getMagnitudes()
        for i in 0...1 {
            mags[i] = 0
        }
        var max_mag: Float = 0.0
        var max_mag_idx = -1
        for i in 0...7 {
            if mags[i] > max_mag {
                max_mag = mags[i]
                max_mag_idx = i
            }
        }
        
        if max_mag_idx == 2 || max_mag_idx == 3 {
            last16[idx_last16] = 1
        } else if max_mag_idx == 5 || max_mag_idx == 6 {
            last16[idx_last16] = -1
        } else {
            last16[idx_last16] = 0
        }
        idx_last16 += 1
        
        if idx_last16 == 15 {
            idx_last16 = 0
            var total = 0
            for i in 0...14 {
                total += last16[i]
            }
            
            if total > 0 {
                candidate_bits[idx_cand] = 1
            } else if total < 0 {
                candidate_bits[idx_cand] = 0
            } else {
                candidate_bits[idx_cand] = -1
            }
            idx_cand += 1
            
            if start_idx == -1 && idx_cand >= 8 {
                var dist = 0
                for i in 0...7 {
                    if candidate_bits[idx_cand - 8 + i] != start_sequence[i] {
                        dist += 1
                    }
                }
                if dist <= 0 {
                    start_idx = idx_cand
                }
            }
            
            if (idx_cand - start_idx) % 2 == 0 && idx_cand > start_idx && start_idx != -1 {
                if candidate_bits[idx_cand - 1] == 0 || candidate_bits[idx_cand - 2] == 0 {
                    bits[idx_bits] = 0
                } else if candidate_bits[idx_cand - 1] == 1 || candidate_bits[idx_cand - 2] == 1 {
                    bits[idx_bits] = 1
                } else {
                    bits[idx_bits] = -1
                }
                idx_bits += 1
            }
            
            if idx_bits == 20 {
                print(bits)
            }
        }
        
        tempi_dispatch_main { () -> () in
            self.gestureView.water_class = max_mag_idx
            self.gestureView.setNeedsDisplay()
        }
        
        
    }
  
    
    func imageFromSampleBuffer(sampleBuffer : CMSampleBuffer) -> UIImage
    {
      // Get a CMSampleBuffer's Core Video image buffer for the media data
      let  imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
      // Lock the base address of the pixel buffer
      CVPixelBufferLockBaseAddress(imageBuffer!, CVPixelBufferLockFlags.readOnly);


      // Get the number of bytes per row for the pixel buffer
      let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer!);

      // Get the number of bytes per row for the pixel buffer
      let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer!);
      // Get the pixel buffer width and height
      let width = CVPixelBufferGetWidth(imageBuffer!);
      let height = CVPixelBufferGetHeight(imageBuffer!);

      // Create a device-dependent RGB color space
      let colorSpace = CGColorSpaceCreateDeviceRGB();

      // Create a bitmap graphics context with the sample buffer data
      var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Little.rawValue
      bitmapInfo |= CGImageAlphaInfo.premultipliedFirst.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
      //let bitmapInfo: UInt32 = CGBitmapInfo.alphaInfoMask.rawValue
      let context = CGContext.init(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
      // Create a Quartz image from the pixel data in the bitmap graphics context
      let quartzImage = context?.makeImage();
      // Unlock the pixel buffer
      CVPixelBufferUnlockBaseAddress(imageBuffer!, CVPixelBufferLockFlags.readOnly);

      // Create an image object from the Quartz image
      let image = UIImage.init(cgImage: quartzImage!);

      return (image);
    }
    
    func resizeImage(image: UIImage, newWidth: CGFloat) -> UIImage {

        let scale = newWidth / image.size.width
        let newHeight = image.size.height * scale
        UIGraphicsBeginImageContext(CGSize(width: newWidth, height: newHeight))
        image.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage!
    }
}



extension UIImage {
   func pixelData() -> [UInt8]? {
       let size = self.size
       let dataSize = size.width * size.height * 4
       var pixelData = [UInt8](repeating: 0, count: Int(dataSize))
       let colorSpace = CGColorSpaceCreateDeviceRGB()
       let context = CGContext(data: &pixelData,
                               width: Int(size.width),
                               height: Int(size.height),
                               bitsPerComponent: 8,
                               bytesPerRow: 4 * Int(size.width),
                               space: colorSpace,
                               bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
       guard let cgImage = self.cgImage else { return nil }
       context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))

       return pixelData
   }
    
    func resizeImage(_ dimension: CGFloat, opaque: Bool) -> UIImage {
        var width: CGFloat
        var height: CGFloat
        var newImage: UIImage

        let size = self.size
        let aspectRatio =  size.width/size.height

        
        height = dimension
        width = dimension * aspectRatio

        if #available(iOS 10.0, *) {
            let renderFormat = UIGraphicsImageRendererFormat.default()
            renderFormat.opaque = opaque
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: renderFormat)
            newImage = renderer.image {
                (context) in
                self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
            }
        } else {
            UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), opaque, 0)
                self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
                newImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
        }

        return newImage
    }
}



extension AVCaptureDevice {
    func set(frameRate: Double) {
    guard let range = activeFormat.videoSupportedFrameRateRanges.first,
        range.minFrameRate...range.maxFrameRate ~= frameRate
        else {
            print("Requested FPS is not supported by the device's activeFormat !")
            return
    }

    do { try lockForConfiguration()
        activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
        activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
        unlockForConfiguration()
    } catch {
        print("LockForConfiguration failed with error: \(error.localizedDescription)")
    }
  }
}



func tempi_dispatch_main(closure:@escaping ()->()) {
    DispatchQueue.main.async {
        closure()
    }
}
