//
//  Warg.swift
//  CameleoniOS
//
//  Created by Iman Zarrabian on 06/01/16.
//  Copyright © 2016 One More Thing Studio. All rights reserved.
//

import Foundation
import UIKit
import ObjectiveC

/**
 The strategy used to find the right forground color
 
 - ColorMatchingStrategyLinear: The same factor is applied to the RGB values when incrasing or decreasing them
 */

public enum ColorMatchingStrategy {
    case ColorMatchingStrategyLinear
    
    /// The human readable name of the strategy
    public var name: String {
        switch self {
        case .ColorMatchingStrategyLinear:
            return "Linear Strategy"
        }
    }
}


/**
 Warg Error Types
 - InvalidBackgroundContent: The extension is unable to make colors computations (average color) on the background (for exemple a CGRectZero value is passed as the computation Rect).
 */
public enum WargError: ErrorType {
    case InvalidBackgroundContent
}


public extension UIView {
    
    /**
     Returns the first visible color by humans for a foreground content when displayed on the top of the receiver.
     
     - Parameter rect:  The rect (in the receiver coordinates) in which the forground content will be displayed.
     - Parameter preferredColor: The color that you would preferaly like to use (this is usually the color given by a creative). This param is optional and the default value will be the color of the receiver in the rect provided.
     - Parameter strategy: The startegy that will be applied when modifying the prefered color to find the first visible one. This param is optional and the default value is ColorMatchingStrategy.ColorMatchingStrategyLinear.
     - Parameter isVerbose: A boolean indicating if the alogithm should print all the steps during computation. This param is optional and the default value is false.

     
     - Throws: `WargError.InvalidBackgroundContent` if the rect parameter does not permit colors computations (for exemple a CGRectZero value).
     
     - Returns: The first visible color found.
     */
    
    public func firstReadableColorInRect(rect: CGRect, preferredColor: UIColor? = nil, strategy: ColorMatchingStrategy = .ColorMatchingStrategyLinear, isVerbose: Bool = false) throws -> UIColor {
        
        //Setting the debug opt-in
        self.isVerbose = isVerbose
        
        guard let image = getImageCaptureRect(rect, view: self) else {
            throw WargError.InvalidBackgroundContent
        }
        
        let color = averageColor(image)
        
        if let prefColor = preferredColor {
            return readableColorColorForBackgroundColor(color, fromColor:prefColor, strategy: strategy)
        }
        else {
            return readableColorColorForBackgroundColor(color, fromColor:color, strategy: strategy)
        }
    }
    
    private func hexStringFromColor(color: UIColor) -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb: Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        
        return NSString(format:"#%06x", rgb) as String
    }
    
    private func getImageCaptureRect(rect: CGRect, view: UIView) -> UIImage? {
        UIGraphicsBeginImageContext(view.bounds.size)
        if let context = UIGraphicsGetCurrentContext() {
            view.layer.renderInContext(context)
        }
        else {
            return nil
        }
        let viewImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        if let imageRef = CGImageCreateWithImageInRect(viewImage.CGImage, rect) {
            let img = UIImage(CGImage: imageRef)
            return img
        }
        else {
            return nil
        }
    }
    
    private func averageColor(image: UIImage) -> UIColor {
        //Based on Mircea "Bobby" Georgescu work http://www.bobbygeorgescu.com/2011/08/finding-average-color-of-uiimage/
        
        let colorSpace = CGColorSpaceCreateDeviceRGB();
        
        let rgba = UnsafeMutablePointer<CUnsignedChar>.alloc(4)
        
        var bitmapInfo =  CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedLast.rawValue)
        let rawBitmapInfo = bitmapInfo.rawValue | CGBitmapInfo.ByteOrder32Big.rawValue
        bitmapInfo = CGBitmapInfo(rawValue: rawBitmapInfo)
        
        let context = CGBitmapContextCreate(rgba, 1, 1, 8, 4, colorSpace, bitmapInfo.rawValue)
        CGContextDrawImage(context, CGRectMake(0, 0, 1, 1), image.CGImage)
        
        if(CGFloat(rgba[3]) > 0) {
            let alpha = CGFloat(CGFloat(rgba[3])/255.0)
            let multiplier = alpha/255.0
            
            return UIColor(red: CGFloat(rgba[0]) * multiplier, green: CGFloat(rgba[1]) * multiplier, blue: CGFloat(rgba[2]) * multiplier, alpha: alpha)
        }
        else {
            return UIColor(red: CGFloat(rgba[0])/255.0, green: CGFloat(rgba[1])/255.0, blue: CGFloat(rgba[2])/255.0, alpha: CGFloat(rgba[3])/255.0)
        }
    }
    
    
    private func darknessScoreOfColor(color: UIColor) -> CGFloat {
        //Using the W3C constrast technics http://www.w3.org/WAI/ER/WD-AERT/#color-contrast
        
        let count = CGColorGetNumberOfComponents(color.CGColor)
        let componentColors = CGColorGetComponents(color.CGColor)
        var darknessScore = 0.0
        if (count == 2) {
            let a = (componentColors[0]*255) * 299
            let b = (componentColors[0]*255) * 587
            let c = (componentColors[0]*255) * 114
            darknessScore = Double(a + b + c) / 1000
        } else if (count == 4) {
            let a = (componentColors[0]*255) * 299
            let b = (componentColors[1]*255) * 587
            let c = (componentColors[2]*255) * 114
            
            darknessScore = Double (a + b + c) / 1000
        }
        return CGFloat(darknessScore)
    }
    
    private func colorScoreDifference(color1: UIColor, color2: UIColor) -> CGFloat {
        //Using the W3C constrast technics http://www.w3.org/WAI/ER/WD-AERT/#color-contrast
        //Color difference is determined by the following formula
        
        let componentColors1 = CGColorGetComponents(color1.CGColor);
        let componentColors2 = CGColorGetComponents(color2.CGColor);
        
        let red1 = componentColors1[0]*255
        let red2 = componentColors2[0]*255
        let green1 = componentColors1[1]*255
        let green2 = componentColors2[1]*255
        let blue1 = componentColors1[2]*255
        let blue2 = componentColors2[2]*255
        
        let firstOperand = max(red1, red2) - min(red1, red2)
        let secondoperand = max(green1, green2) - min(green1, green2)
        let thirdOperand = max(blue1, blue2) - min(blue1, blue2)
        
        return firstOperand + secondoperand + thirdOperand
    }
    
    
    private func readableColorColorForBackgroundColor(backgroundColor: UIColor, fromColor: UIColor, strategy: ColorMatchingStrategy) -> UIColor {
        
        let bgDarknessScore = darknessScoreOfColor(backgroundColor)
        let count = CGColorGetNumberOfComponents(fromColor.CGColor);
        let componentColors = CGColorGetComponents(fromColor.CGColor);
        var madeColor = fromColor
        
        var r = 0.0
        var g = 0.0
        var b = 0.0
        
        if (count == 2) {
            r = Double(componentColors[0] * CGFloat(255.0))
            g = Double(componentColors[0] * CGFloat(255.0))
            b = Double(componentColors[0] * CGFloat(255.0))
        }
        else if (count == 4) {
            r = Double(componentColors[0] * CGFloat(255.0))
            g = Double(componentColors[1] * CGFloat(255.0))
            b = Double(componentColors[2] * CGFloat(255.0))
        }
        wargPrint("\nBackground color: " + hexStringFromColor(backgroundColor)  + "\n")
        wargPrint("\nFind right color using " + strategy.name)

        if strategy == .ColorMatchingStrategyLinear {
           
            if (bgDarknessScore >= 125) {
                //Background is made of a light color
                //We have to decrease RGB values of the from color
                wargPrint("******")
                wargPrint("Decreasing")
                wargPrint("******\n")
                
                for var index = 55; index > 0; index-- {
                    
                    let factor = Double(index) / 55.0
                    
                    r = r > 1.0 ? r * Double(factor) : 0.0;
                    g = g > 1.0 ? g * Double(factor) : 0.0;
                    b = b > 1.0 ? b * Double(factor) : 0.0;
                    
                    //Rounding down the doubles
                    r = floor(r)
                    g = floor(g)
                    b = floor(b)
                    
                    madeColor = UIColor(red: CGFloat(r/255.0), green: CGFloat(g/255.0), blue: CGFloat(b/255.0), alpha: 1)
                    let factorFormatted = NSString(format: "%.2f", factor * 100.0)
                    
                    wargPrint((factorFormatted as String) + "% Candidate " + hexStringFromColor(madeColor))
                
                    
                    let madeColorDarkness = darknessScoreOfColor(madeColor)
                    let colordifference = colorScoreDifference(backgroundColor, color2:madeColor)
                    
                    wargPrint("BDiff \(fabs(madeColorDarkness - bgDarknessScore)) - CDiff \(colordifference)")
                    
                    if (fabs(madeColorDarkness - bgDarknessScore)  >= 125.0 && colordifference >= 300.0) {
                        wargPrint("\n==================================================")
                        wargPrint("Elected Candidate " + hexStringFromColor(madeColor))
                        wargPrint("BDiff \(fabs(madeColorDarkness - bgDarknessScore)) - CDiff \(colordifference)")
                        wargPrint("==================================================\n")
                        break
                    }
                }
            }
            else {
                
                //Background is made of a dark color
                //We have to increase RGB values of the from color
                wargPrint("******")
                wargPrint("Increasing")
                wargPrint("******\n")
                
                for var index = 0; index < 55; index++ {
                    
                    let factor = Double(index) / 55.0
                    
                    r = r < 255.0 ? (r + r * Double(factor) + 1.0) : 255.0
                    g = g < 255.0 ? (g + g * Double(factor) + 1.0) : 255.0
                    b = b < 255.0 ? (b + b * Double(factor) + 1.0) : 255.0
                    
                    //Rounding down the doubles
                    r = floor(r)
                    g = floor(g)
                    b = floor(b)

                    madeColor = UIColor(red: CGFloat(r/255.0), green: CGFloat(g/255.0), blue: CGFloat(b/255.0), alpha: 1)
                    let factorFormatted = NSString(format: "%.2f", factor * 100.0)
                    wargPrint((factorFormatted as String) + "% Candidate " + hexStringFromColor(madeColor))
                    
                    let madeColorDarkness = darknessScoreOfColor(madeColor)
                    let colordifference = colorScoreDifference(backgroundColor, color2:madeColor)
                    
                    wargPrint("BDiff \(fabs(madeColorDarkness - bgDarknessScore)) - CDiff \(colordifference)")
                    
                    if (fabs(madeColorDarkness - bgDarknessScore)  >= 125.0 && colordifference >= 300.0) {
                        wargPrint("\n=============================================================")
                        wargPrint("Elected Candidate " + hexStringFromColor(madeColor))
                        wargPrint("BDiff \(fabs(madeColorDarkness - bgDarknessScore)) - CDiff \(colordifference)")
                        wargPrint("=============================================================\n")
                        break
                    }
                }
            }
        }
        return madeColor
    }
}

//Debugging extension
private extension UIView {
    
    struct GlobalVariables {
        static var staticKey: Int = 42
    }
    
    var isVerbose: Bool {
        get {
            return objc_getAssociatedObject(self, &GlobalVariables.staticKey) as! Bool
        }
        set {
            objc_setAssociatedObject(self, &GlobalVariables.staticKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func wargPrint(message: String) {
        if self.isVerbose {
            print(message)
        }
    }
}
