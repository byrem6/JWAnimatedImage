//
//  JWAnimatedImageView
//
//  Created by 王佳玮 on 16/2/21.
//  Copyright © 2016年 jw. All rights reserved.
//

import ImageIO
import UIKit

public class JWAnimatedImageView:UIImageView
{
    
    
    
    //bound to function 'updateFrame'
    private lazy var displayLink: CADisplayLink = CADisplayLink(target: self, selector: Selector("updateFrame"))
    
    // obtained from NSData
    private var imageSource: CGImageSourceRef?
    
    //as a frame cache queue,obtained by 'frameProducter',max size is 'frameCacheMaxNumber'
    private var frameCache = [UIImage]()
    
    //frameCacheMaxNumber's default is 5
    private var frameCacheMaxNumber = 5
    public func setFrameCacheMaxNumber(newFrameCacheMaxNumber:Int)
        {self.frameCacheMaxNumber = newFrameCacheMaxNumber}
    
    //indexs of frames choosed from imageSource and total number
    private var displayOrder = [Int]()
    private var imageCount = 0  //initial
    
    
    //the level of integrity of a gif image,The range is 0%(0)~100%(1).we know that CADisplayLink.frameInterval affact the display frames per second,if it is larger, we will only dispaly fewer frames per second,in the other way,we will never display some of frames all the time.So,the level of integrity gives us a limit that the device should show how many frames at list.If it is 100%(1),that means the device displays frames as much as it can.The default number is 0.8,but you can decrease it for a less cpu usage.
    private var levelOfIntegrity:Float = 0.8    //default
    private var displayRefreshFactors = 1   //default
    public func setLevelOfIntegrity(newLevelOfIntegrity:Float)
        {self.levelOfIntegrity = newLevelOfIntegrity}
    
    
    
    //add gif as NSData
    public func addGifImage(data:NSData){
        self.imageSource = CGImageSourceCreateWithData(data, nil)
        
        //set cover
        image = UIImage(CGImage: CGImageSourceCreateImageAtIndex(self.imageSource!,0,nil)!)//cover
        //self.layer.setNeedsDisplay()

        CalculateFrameDelay(GetDelayTimes())
        setCurrentImage()
        
        self.displayLink.frameInterval = self.displayRefreshFactors
        self.displayLink.addToRunLoop(.mainRunLoop(), forMode: NSRunLoopCommonModes)
    }
    
    public var currentImage:UIImage?
    
    //the current index of frames when display the gif
    private var displayOrderIndex = 0
    
    //this is an empty function,but program won't work if I delete it,and I don't know why
    override public func displayLayer(layer: CALayer){}
    
    //bound to 'displayLink'
    func updateFrame(){
        image = self.currentImage
        //self.layer.setNeedsDisplay()
        dispatch_async(queue,setCurrentImage)
    }
    
    let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH,0)
    
    

    func setCurrentImage()
    {
        if(self.frameCache.count == 0){frameProducter()}
        frameConsumer()
    }
    
    
    //product UIImage into frameCache
    private func frameProducter(){
            for _ in 0..<self.frameCacheMaxNumber{
            let cgImage = CGImageSourceCreateImageAtIndex(self.imageSource!,self.displayOrder[self.displayOrderIndex],nil)!
            self.frameCache.append(UIImage(CGImage:cgImage))
            self.displayOrderIndex = (self.displayOrderIndex+1)%self.imageCount
            }
    }


    //get the first image from frameCache,and remove it
    private func frameConsumer(){
        self.currentImage = self.frameCache.first
        self.frameCache.removeFirst()
    }
    
    
    private func GetDelayTimes()->[Float]{
        
        let imageCount = CGImageSourceGetCount(imageSource!)
        
        var imageProperties = [CFDictionary]()
        for i in 0..<imageCount{
            imageProperties.append(CGImageSourceCopyPropertiesAtIndex(imageSource!, i, nil)!)
        }
        
        let frameProperties = imageProperties.map(){
                unsafeBitCast(
                    CFDictionaryGetValue($0,
                        unsafeAddressOf(kCGImagePropertyGIFDictionary)),                CFDictionary.self)
        }
        
        let frameDelays:[Float] = frameProperties.map(){
            var delayObject: AnyObject = unsafeBitCast(
                    CFDictionaryGetValue($0,
                        unsafeAddressOf(kCGImagePropertyGIFUnclampedDelayTime)),
                    AnyObject.self)
            let EPS = 10e-10
            if(delayObject.doubleValue<EPS){
                delayObject = unsafeBitCast(CFDictionaryGetValue($0,
                        unsafeAddressOf(kCGImagePropertyGIFDelayTime)), AnyObject.self)
            }
            return delayObject as! Float
        }
        return frameDelays
    }
    
    typealias FrameDelays = [Float]
    private func CalculateFrameDelay(var delays:FrameDelays)
    {
        
        //Factors send to CADisplayLink.frameInterval
        let displayRefreshFactors = [60,30,20,15,12,10,6,5,4,3,2,1,]
        
        //maxFramePerSecond,default is 60
        let maxFramePerSecond = displayRefreshFactors.first
        
        //frame numbers per second
        let displayRefreshRates = displayRefreshFactors.map{maxFramePerSecond!/$0}
        
        //time interval per frame
        let displayRefreshDelayTime = displayRefreshRates.map{1.0/Float($0)}
        
        //caclulate the time when eash frame should be displayed at(start at 0)
        for i in 1..<delays.count{ delays[i]+=delays[i-1] }
        
        //find the appropriate Factors then BREAK
        for i in 0..<displayRefreshDelayTime.count{
            
            let displayPosition = delays.map{Int($0/displayRefreshDelayTime[i])}
            
            var framelosecount = 0
            for j in 1..<displayPosition.count{
                if(displayPosition[j] == displayPosition[j-1])
                    {++framelosecount}
            }

            if(Float(framelosecount) <= Float(displayPosition.count) * (1.0 - self.levelOfIntegrity)||i==displayRefreshDelayTime.count-1){
                
                self.imageCount = displayPosition.last!
                self.displayRefreshFactors = displayRefreshFactors[i]

                var indexOfold = 0
                var indexOfnew = 0
                
                while(indexOfnew<self.imageCount)
                {
                    if(indexOfnew <= displayPosition[indexOfold])
                    {
                        self.displayOrder.append(indexOfold)
                        ++indexOfnew
                    }else{++indexOfold}
                }
                break
            }
        }
    }
}