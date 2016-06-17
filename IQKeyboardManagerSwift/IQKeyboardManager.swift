//
//  IQKeyboardManager.swift
// https://github.com/hackiftekhar/IQKeyboardManager
// Copyright (c) 2013-16 Iftekhar Qurashi.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


import Foundation
import CoreGraphics
import UIKit

///---------------------
/// MARK: IQToolbar tags
///---------------------

/**
Codeless drop-in universal library allows to prevent issues of keyboard sliding up and cover UITextField/UITextView. Neither need to write any code nor any setup required and much more. A generic version of KeyboardManagement. https://developer.apple.com/library/ios/documentation/StringsTextFonts/Conceptual/TextAndWebiPhoneOS/KeyboardManagement/KeyboardManagement.html
*/

public class IQKeyboardManager: NSObject, UIGestureRecognizerDelegate {
    
    /**
    Default tag for toolbar with Done button   -1002.
    */
    private static let  kIQDoneButtonToolbarTag         =   -1002
    
    /**
    Default tag for toolbar with Previous/Next buttons -1005.
    */
    private static let  kIQPreviousNextButtonToolbarTag =   -1005
    
    ///---------------------------
    ///  MARK: UIKeyboard handling
    ///---------------------------
    
    /**
     Registered classes list with library.
     */
    private var registeredClasses  = [UIView.Type]()
    
    /**
    Enable/disable managing distance between keyboard and textField. Default is YES(Enabled when class loads in `+(void)load` method).
    */
    public var enable = false {
        
        didSet {
            //If not enable, enable it.
            if enable == true && oldValue == false {
                //If keyboard is currently showing. Sending a fake notification for keyboardWillShow to adjust view according to keyboard.
                if _kbShowNotification != nil {
                    keyboardWillShow(_kbShowNotification)
                }
                showLog("enabled")
            } else if enable == false && oldValue == true {   //If not disable, desable it.
                keyboardWillHide(nil)
                showLog("disabled")
            }
        }
    }
    
    public func privateIsEnabled()-> Bool {
        
        var isEnabled = enable
        
        if let textFieldViewController = _textFieldView?.viewController() {
            
            if isEnabled == false {
                
                //If viewController is kind of enable viewController class, then assuming it's enabled.
                for enabledClass in enabledDistanceHandlingClasses {
                    
                    if textFieldViewController.isKindOfClass(enabledClass) {
                        isEnabled = true
                        break
                    }
                }
            }
            
            if isEnabled == true {
                
                //If viewController is kind of disabled viewController class, then assuming it's disabled.
                for disabledClass in disabledDistanceHandlingClasses {
                    
                    if textFieldViewController.isKindOfClass(disabledClass) {
                        isEnabled = false
                        break
                    }
                }
            }
        }
        
        return isEnabled
    }
    
    /**
    To set keyboard distance from textField. can't be less than zero. Default is 10.0.
    */
    public var keyboardDistanceFromTextField: CGFloat {
        
        set {
            _privateKeyboardDistanceFromTextField =  max(0, newValue)
            showLog("keyboardDistanceFromTextField: \(_privateKeyboardDistanceFromTextField)")
        }
        get {
            return _privateKeyboardDistanceFromTextField
        }
    }

    /**
    Prevent keyboard manager to slide up the rootView to more than keyboard height. Default is YES.
    */
    public var preventShowingBottomBlankSpace = true
    
    /**
    Returns the default singleton instance.
    */
    public class func sharedManager() -> IQKeyboardManager {
        
        struct Static {
            //Singleton instance. Initializing keyboard manger.
            static let kbManager = IQKeyboardManager()
        }
        
        /** @return Returns the default singleton instance. */
        return Static.kbManager
    }
    
    ///-------------------------
    /// MARK: IQToolbar handling
    ///-------------------------
    
    /**
    Automatic add the IQToolbar functionality. Default is YES.
    */
    public var enableAutoToolbar = true {
        
        didSet {

            privateIsEnableAutoToolbar() ?addToolbarIfRequired():removeToolbarIfRequired()

            let enableToolbar = enableAutoToolbar ? "Yes" : "NO"

            showLog("enableAutoToolbar: \(enableToolbar)")
        }
    }
    
    private func privateIsEnableAutoToolbar() -> Bool {
        
        var enableToolbar = enableAutoToolbar
        
        if let textFieldViewController = _textFieldView?.viewController() {
            
            if enableToolbar == false {
                
                //If found any toolbar enabled classes then return.
                for enabledClass in enabledToolbarClasses {
                    
                    if textFieldViewController.isKindOfClass(enabledClass) {
                        enableToolbar = true
                        break
                    }
                }
            }
            
            if enableToolbar == true {
                
                //If found any toolbar disabled classes then return.
                for disabledClass in disabledToolbarClasses {
                    
                    if textFieldViewController.isKindOfClass(disabledClass) {
                        enableToolbar = false
                        break
                    }
                }
            }
        }

        return enableToolbar
    }

    /**
    AutoToolbar managing behaviour. Default is IQAutoToolbarBySubviews.
    */
    public var toolbarManageBehaviour = IQAutoToolbarManageBehaviour.BySubviews

    /**
    If YES, then uses textField's tintColor property for IQToolbar, otherwise tint color is black. Default is NO.
    */
    public var shouldToolbarUsesTextFieldTintColor = false
    
    /**
    This is used for toolbar.tintColor when textfield.keyboardAppearance is UIKeyboardAppearanceDefault. If shouldToolbarUsesTextFieldTintColor is YES then this property is ignored. Default is nil and uses black color.
    */
    public var toolbarTintColor : UIColor?

    /**
     If YES, then hide previous/next button. Default is NO.
     */
    public var shouldHidePreviousNext = false

    /**
     Toolbar done button icon, If nothing is provided then check toolbarDoneBarButtonItemText to draw done button.
     */
    public var toolbarDoneBarButtonItemImage : UIImage?
    
    /**
     Toolbar done button text, If nothing is provided then system default 'UIBarButtonSystemItemDone' will be used.
     */
    public var toolbarDoneBarButtonItemText : String?

    /**
    If YES, then it add the textField's placeholder text on IQToolbar. Default is YES.
    */
    public var shouldShowTextFieldPlaceholder = true
    
    /**
    Placeholder Font. Default is nil.
    */
    public var placeholderFont: UIFont?
    
    
    ///--------------------------
    /// MARK: UITextView handling
    ///--------------------------
    
    /** used to adjust contentInset of UITextView. */
    private var         startingTextViewContentInsets = UIEdgeInsetsZero
    
    /** used to adjust scrollIndicatorInsets of UITextView. */
    private var         startingTextViewScrollIndicatorInsets = UIEdgeInsetsZero
    
    /** used with textView to detect a textFieldView contentInset is changed or not. (Bug ID: #92)*/
    private var         isTextViewContentInsetChanged = false
    
    /*******************************************/
    

    /**
    Adjust textView's frame when it is too big in height. Default is NO.
    */
    @available(*,deprecated, message="Now adjusting UITextView is automatically handled by adjusting contentInset property of UITextView(UIScrollView) internally, so there is no need of this property and will be removed in future releases.")
    public var canAdjustTextView = false


    ///---------------------------------------
    /// MARK: UIKeyboard appearance overriding
    ///---------------------------------------

    /**
    Override the keyboardAppearance for all textField/textView. Default is NO.
    */
    public var overrideKeyboardAppearance = false
    
    /**
    If overrideKeyboardAppearance is YES, then all the textField keyboardAppearance is set using this property.
    */
    public var keyboardAppearance = UIKeyboardAppearance.Default

    
    ///-----------------------------------------------------------
    /// MARK: UITextField/UITextView Next/Previous/Resign handling
    ///-----------------------------------------------------------
    
    
    /**
    Resigns Keyboard on touching outside of UITextField/View. Default is NO.
    */
    public var shouldResignOnTouchOutside = false {
        
        didSet {
            _tapGesture.enabled = privateShouldResignOnTouchOutside()
            
            let shouldResign = shouldResignOnTouchOutside ? "Yes" : "NO"
            
            showLog("shouldResignOnTouchOutside: \(shouldResign)")
        }
    }
    
    private func privateShouldResignOnTouchOutside() -> Bool {
        
        var shouldResign = shouldResignOnTouchOutside
        
        if let textFieldViewController = _textFieldView?.viewController() {
            
            if shouldResign == false {
                
                //If viewController is kind of enable viewController class, then assuming shouldResignOnTouchOutside is enabled.
                for enabledClass in enabledTouchResignedClasses {
                    
                    if textFieldViewController.isKindOfClass(enabledClass) {
                        shouldResign = true
                        break
                    }
                }
            }
            
            if shouldResign == true {
                
                //If viewController is kind of disable viewController class, then assuming shouldResignOnTouchOutside is disable.
                for disabledClass in disabledTouchResignedClasses {
                    
                    if textFieldViewController.isKindOfClass(disabledClass) {
                        shouldResign = false
                        break
                    }
                }
            }
        }
        
        return shouldResign
    }
    
    /**
    Resigns currently first responder field.
    */
    public func resignFirstResponder()-> Bool {
        
        if let textFieldRetain = _textFieldView {
            
            //Resigning first responder
            let isResignFirstResponder = textFieldRetain.resignFirstResponder()
            
            //  If it refuses then becoming it as first responder again.    (Bug ID: #96)
            if isResignFirstResponder == false {
                //If it refuses to resign then becoming it first responder again for getting notifications callback.
                textFieldRetain.becomeFirstResponder()
                
                showLog("Refuses to resign first responder: \(_textFieldView?._IQDescription())")
            }
            
            return isResignFirstResponder
        }
        
        return false
    }
    
    /**
    Returns YES if can navigate to previous responder textField/textView, otherwise NO.
    */
    public var canGoPrevious: Bool {
        
        get {
            //Getting all responder view's.
            if let textFields = responderViews() {
                if let  textFieldRetain = _textFieldView {
                    
                    //Getting index of current textField.
                    if let index = textFields.indexOf(textFieldRetain) {
                        
                        //If it is not first textField. then it's previous object canBecomeFirstResponder.
                        if index > 0 {
                            return true
                        }
                    }
                }
            }
            return false
        }
    }
    
    /**
    Returns YES if can navigate to next responder textField/textView, otherwise NO.
    */
    public var canGoNext: Bool {
        
        get {
            //Getting all responder view's.
            if let textFields = responderViews() {
                if let  textFieldRetain = _textFieldView {
                    //Getting index of current textField.
                    if let index = textFields.indexOf(textFieldRetain) {
                        
                        //If it is not first textField. then it's previous object canBecomeFirstResponder.
                        if index < textFields.count-1 {
                            return true
                        }
                    }
                }
            }
            return false
        }
    }
    
    /**
    Navigate to previous responder textField/textView.
    */
    public func goPrevious()-> Bool {
        
        //Getting all responder view's.
        if let  textFieldRetain = _textFieldView {
            if let textFields = responderViews() {
                //Getting index of current textField.
                if let index = textFields.indexOf(textFieldRetain) {
                    
                    //If it is not first textField. then it's previous object becomeFirstResponder.
                    if index > 0 {
                        
                        let nextTextField = textFields[index-1]
                        
                        let isAcceptAsFirstResponder = nextTextField.becomeFirstResponder()
                        
                        //  If it refuses then becoming previous textFieldView as first responder again.    (Bug ID: #96)
                        if isAcceptAsFirstResponder == false {
                            //If next field refuses to become first responder then restoring old textField as first responder.
                            textFieldRetain.becomeFirstResponder()
                            
                            showLog("Refuses to become first responder: \(nextTextField._IQDescription())")
                        }
                        
                        return isAcceptAsFirstResponder
                    }
                }
            }
        }
        
        return false
    }
    
    /**
    Navigate to next responder textField/textView.
    */
    public func goNext()-> Bool {

        //Getting all responder view's.
        if let  textFieldRetain = _textFieldView {
            if let textFields = responderViews() {
                //Getting index of current textField.
                if let index = textFields.indexOf(textFieldRetain) {
                    //If it is not last textField. then it's next object becomeFirstResponder.
                    if index < textFields.count-1 {
                        
                        let nextTextField = textFields[index+1]
                        
                        let isAcceptAsFirstResponder = nextTextField.becomeFirstResponder()
                        
                        //  If it refuses then becoming previous textFieldView as first responder again.    (Bug ID: #96)
                        if isAcceptAsFirstResponder == false {
                            //If next field refuses to become first responder then restoring old textField as first responder.
                            textFieldRetain.becomeFirstResponder()
                            
                            showLog("Refuses to become first responder: \(nextTextField._IQDescription())")
                        }
                        
                        return isAcceptAsFirstResponder
                    }
                }
            }
        }

        return false
    }
    
    /**	previousAction. */
    internal func previousAction (barButton : UIBarButtonItem?) {
        
        //If user wants to play input Click sound.
        if shouldPlayInputClicks == true {
            //Play Input Click Sound.
            UIDevice.currentDevice().playInputClick()
        }
        
        if canGoPrevious == true {
            
            if let textFieldRetain = _textFieldView {
                let isAcceptAsFirstResponder = goPrevious()
                
                if isAcceptAsFirstResponder && textFieldRetain.previousInvocation.target != nil && textFieldRetain.previousInvocation.action != nil {
                    
                    UIApplication.sharedApplication().sendAction(textFieldRetain.previousInvocation.action!, to: textFieldRetain.previousInvocation.target, from: textFieldRetain, forEvent: UIEvent())
                }
            }
        }
    }
    
    /**	nextAction. */
    internal func nextAction (barButton : UIBarButtonItem?) {
        
        //If user wants to play input Click sound.
        if shouldPlayInputClicks == true {
            //Play Input Click Sound.
            UIDevice.currentDevice().playInputClick()
        }
        
        if canGoNext == true {
            
            if let textFieldRetain = _textFieldView {
                let isAcceptAsFirstResponder = goNext()
                
                if isAcceptAsFirstResponder && textFieldRetain.nextInvocation.target != nil && textFieldRetain.nextInvocation.action != nil {
                    
                    UIApplication.sharedApplication().sendAction(textFieldRetain.nextInvocation.action!, to: textFieldRetain.nextInvocation.target, from: textFieldRetain, forEvent: UIEvent())
                }
            }
        }
    }
    
    /**	doneAction. Resigning current textField. */
    internal func doneAction (barButton : IQBarButtonItem?) {
        
        //If user wants to play input Click sound.
        if shouldPlayInputClicks == true {
            //Play Input Click Sound.
            UIDevice.currentDevice().playInputClick()
        }
        
        if let textFieldRetain = _textFieldView {
            //Resign textFieldView.
            let isResignedFirstResponder = resignFirstResponder()
            
            if isResignedFirstResponder && textFieldRetain.doneInvocation.target != nil  && textFieldRetain.doneInvocation.action != nil{
                
                UIApplication.sharedApplication().sendAction(textFieldRetain.doneInvocation.action!, to: textFieldRetain.doneInvocation.target, from: textFieldRetain, forEvent: UIEvent())
            }
        }
    }
    
    /** Resigning on tap gesture.   (Enhancement ID: #14)*/
    internal func tapRecognized(gesture: UITapGestureRecognizer) {
        
        if gesture.state == UIGestureRecognizerState.Ended {

            //Resigning currently responder textField.
            resignFirstResponder()
        }
    }
    
    /** Note: returning YES is guaranteed to allow simultaneous recognition. returning NO is not guaranteed to prevent simultaneous recognition, as the other gesture's delegate may return YES. */
    public func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    /** To not detect touch events in a subclass of UIControl, these may have added their own selector for specific work */
    public func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
        //  Should not recognize gesture if the clicked view is either UIControl or UINavigationBar(<Back button etc...)    (Bug ID: #145)
        return (touch.view is UIControl || touch.view is UINavigationBar) ? false : true
    }
    
    ///-----------------------
    /// MARK: UISound handling
    ///-----------------------

    /**
    If YES, then it plays inputClick sound on next/previous/done click.
    */
    public var shouldPlayInputClicks = true
    
    
    ///---------------------------
    /// MARK: UIAnimation handling
    ///---------------------------

    /**
    If YES, then uses keyboard default animation curve style to move view, otherwise uses UIViewAnimationOptionCurveEaseInOut animation style. Default is YES.
    
    @warning Sometimes strange animations may be produced if uses default curve style animation in iOS 7 and changing the textFields very frequently.
    */
    @available(*,deprecated, message="Now there is no animation glitch with default animation style so this property no longer needed and will be removed in future releases")
    public var shouldAdoptDefaultKeyboardAnimation = true

    /**
    If YES, then calls 'setNeedsLayout' and 'layoutIfNeeded' on any frame update of to viewController's view.
    */
    public var layoutIfNeededOnUpdate = false

    ///-----------------------------------------------
    /// @name InteractivePopGestureRecognizer handling
    ///-----------------------------------------------
    
    /**
     If YES, then always consider UINavigationController.view begin point as {0,0}, this is a workaround to fix a bug #464 because there are no notification mechanism exist when UINavigationController.view.frame gets changed internally.
     */
    public var shouldFixInteractivePopGestureRecognizer = true
    
    
    ///------------------------------------
    /// MARK: Class Level disabling methods
    ///------------------------------------
    
    /**
     Disable distance handling within the scope of disabled distance handling viewControllers classes. Within this scope, 'enabled' property is ignored. Class should be kind of UIViewController.
     */
    public var disabledDistanceHandlingClasses  = [UIViewController.Type]()
    
    /**
     Enable distance handling within the scope of enabled distance handling viewControllers classes. Within this scope, 'enabled' property is ignored. Class should be kind of UIViewController. If same Class is added in disabledDistanceHandlingClasses list, then enabledDistanceHandlingClasses will be ignored.
     */
    public var enabledDistanceHandlingClasses  = [UIViewController.Type]()
    
    /**
     Disable automatic toolbar creation within the scope of disabled toolbar viewControllers classes. Within this scope, 'enableAutoToolbar' property is ignored. Class should be kind of UIViewController.
     */
    public var disabledToolbarClasses  = [UIViewController.Type]()
    
    /**
     Enable automatic toolbar creation within the scope of enabled toolbar viewControllers classes. Within this scope, 'enableAutoToolbar' property is ignored. Class should be kind of UIViewController. If same Class is added in disabledToolbarClasses list, then enabledToolbarClasses will be ignore.
     */
    public var enabledToolbarClasses  = [UIViewController.Type]()

    /**
     Allowed subclasses of UIView to add all inner textField, this will allow to navigate between textField contains in different superview. Class should be kind of UIView.
     */
    public var toolbarPreviousNextAllowedClasses  = [UIView.Type]()
    
    /**
     Disabled classes to ignore 'shouldResignOnTouchOutside' property, Class should be kind of UIViewController.
     */
    public var disabledTouchResignedClasses  = [UIViewController.Type]()
    
    /**
     Enabled classes to forcefully enable 'shouldResignOnTouchOutsite' property. Class should be kind of UIViewController. If same Class is added in disabledTouchResignedClasses list, then enabledTouchResignedClasses will be ignored.
     */
    public var enabledTouchResignedClasses  = [UIViewController.Type]()

    ///-------------------------------------------
    /// MARK: Third Party Library support
    /// Add TextField/TextView Notifications customised NSNotifications. For example while using YYTextView https://github.com/ibireme/YYText
    ///-------------------------------------------
    
    /**
    Add customised Notification for third party customised TextField/TextView. Please be aware that the NSNotification object must be idential to UITextField/UITextView NSNotification objects and customised TextField/TextView support must be idential to UITextField/UITextView.
    @param didBeginEditingNotificationName This should be identical to UITextViewTextDidBeginEditingNotification
    @param didEndEditingNotificationName This should be identical to UITextViewTextDidEndEditingNotification
    */
    
    public func registerTextFieldViewClass(aClass: UIView.Type, didBeginEditingNotificationName : String, didEndEditingNotificationName : String) {
        
        registeredClasses.append(aClass)

        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.textFieldViewDidBeginEditing(_:)),    name: didBeginEditingNotificationName, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.textFieldViewDidEndEditing(_:)),      name: didEndEditingNotificationName, object: nil)
    }

    /**************************************************************************************/
    ///------------------------
    /// MARK: Private variables
    ///------------------------

    /*******************************************/

    /** To save UITextField/UITextView object voa textField/textView notifications. */
    private weak var    _textFieldView: UIView?
    
    /** To save rootViewController.view.frame. */
    private var         _topViewBeginRect = CGRectZero
    
    /** To save rootViewController */
    private weak var    _rootViewController: UIViewController?
    
    /** To save topBottomLayoutConstraint original constant */
    private var         _layoutGuideConstraintInitialConstant: CGFloat  = 0.25

    /*******************************************/

    /** Variable to save lastScrollView that was scrolled. */
    private weak var    _lastScrollView: UIScrollView?
    
    /** LastScrollView's initial contentOffset. */
    private var         _startingContentOffset = CGPointZero
    
    /** LastScrollView's initial scrollIndicatorInsets. */
    private var         _startingScrollIndicatorInsets = UIEdgeInsetsZero
    
    /** LastScrollView's initial contentInsets. */
    private var         _startingContentInsets = UIEdgeInsetsZero
    
    /*******************************************/

    /** To save keyboardWillShowNotification. Needed for enable keyboard functionality. */
    private var         _kbShowNotification: NSNotification?
    
    /** To save keyboard size. */
    private var         _kbSize = CGSizeZero
    
    /** To save keyboard animation duration. */
    private var         _animationDuration = 0.25
    
    /** To mimic the keyboard animation */
    private var         _animationCurve = UIViewAnimationOptions.CurveEaseOut
    
    /*******************************************/

    /** TapGesture to resign keyboard on view's touch. */
    private var         _tapGesture: UITapGestureRecognizer!
    
    /*******************************************/
    
    private struct flags {
        /** Boolean to maintain keyboard is showing or it is hide. To solve rootViewController.view.frame calculations. */
        var isKeyboardShowing = false
    }
    
    /** Private flags to use within the project */
    private var         _keyboardManagerFlags = flags(isKeyboardShowing: false)

    /** To use with keyboardDistanceFromTextField. */
    private var         _privateKeyboardDistanceFromTextField: CGFloat = 10.0
    
    /**************************************************************************************/
    
    ///--------------------------------------
    /// MARK: Initialization/Deinitialization
    ///--------------------------------------
    
    /*  Singleton Object Initialization. */
    override init() {
        
        super.init()

        //  Registering for keyboard notification.
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.keyboardWillShow(_:)),                name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.keyboardDidShow(_:)),                name: UIKeyboardDidShowNotification, object: nil)

        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.keyboardWillHide(_:)),                name: UIKeyboardWillHideNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.keyboardDidHide(_:)),                name: UIKeyboardDidHideNotification, object: nil)
        
        //  Registering for UITextField notification.
        registerTextFieldViewClass(UITextField.self, didBeginEditingNotificationName: UITextFieldTextDidBeginEditingNotification, didEndEditingNotificationName: UITextFieldTextDidEndEditingNotification)
        
        //  Registering for UITextView notification.
        registerTextFieldViewClass(UITextView.self, didBeginEditingNotificationName: UITextViewTextDidBeginEditingNotification, didEndEditingNotificationName: UITextViewTextDidEndEditingNotification)
        
        //  Registering for orientation changes notification
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.willChangeStatusBarOrientation(_:)),          name: UIApplicationWillChangeStatusBarOrientationNotification, object: nil)

        //Creating gesture for @shouldResignOnTouchOutside. (Enhancement ID: #14)
        _tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.tapRecognized(_:)))
        _tapGesture.cancelsTouchesInView = false
        _tapGesture.delegate = self
        _tapGesture.enabled = shouldResignOnTouchOutside
        
        disabledDistanceHandlingClasses.append(UITableViewController)
        toolbarPreviousNextAllowedClasses.append(UITableView)
        toolbarPreviousNextAllowedClasses.append(UICollectionView)
        toolbarPreviousNextAllowedClasses.append(IQPreviousNextView)
        //Workaround to load all appearance proxies at startup
        let barButtonItem2 = IQTitleBarButtonItem()
        barButtonItem2.title = ""
        let toolbar = IQToolbar()
        toolbar.title = ""
    }
    
    /** Override +load method to enable KeyboardManager when class loader load IQKeyboardManager. Enabling when app starts (No need to write any code) */
    /** It doesn't work from Swift 1.2 */
//    override public class func load() {
//        super.load()
//        
//        //Enabling IQKeyboardManager.
//        IQKeyboardManager.sharedManager().enable = true
//    }
    
    deinit {
        //  Disable the keyboard manager.
        enable = false

        //Removing notification observers on dealloc.
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    /** Getting keyWindow. */
    private func keyWindow() -> UIWindow? {
        
        if let keyWindow = _textFieldView?.window {
            return keyWindow
        } else {
            
            struct Static {
                /** @abstract   Save keyWindow object for reuse.
                @discussion Sometimes [[UIApplication sharedApplication] keyWindow] is returning nil between the app.   */
                static var keyWindow : UIWindow?
            }

            /*  (Bug ID: #23, #25, #73)   */
            let originalKeyWindow = UIApplication.sharedApplication().keyWindow
            
            //If original key window is not nil and the cached keywindow is also not original keywindow then changing keywindow.
            if originalKeyWindow != nil && (Static.keyWindow == nil || Static.keyWindow != originalKeyWindow) {
                Static.keyWindow = originalKeyWindow
            }

            //Return KeyWindow
            return Static.keyWindow
        }
    }

    ///-----------------------
    /// MARK: Helper Functions
    ///-----------------------
    
    /*  Helper function to manipulate RootViewController's frame with animation. */
    private func setRootViewFrame(frame: CGRect) {
        
        //  Getting topMost ViewController.
        var controller = _textFieldView?.topMostController()
        
        if controller == nil {
            controller = keyWindow()?.topMostController()
        }
        
        if let unwrappedController = controller {
            
            var newFrame = frame
            //frame size needs to be adjusted on iOS8 due to orientation structure changes.
            newFrame.size = unwrappedController.view.frame.size
            
            //Used UIViewAnimationOptionBeginFromCurrentState to minimize strange animations.
            UIView.animateWithDuration(_animationDuration, delay: 0, options: UIViewAnimationOptions.BeginFromCurrentState.union(_animationCurve), animations: { () -> Void in
                
                //  Setting it's new frame
                unwrappedController.view.frame = newFrame
                self.showLog("Set \(controller?._IQDescription()) frame to : \(newFrame)")
                
                //Animating content if needed (Bug ID: #204)
                if self.layoutIfNeededOnUpdate == true {
                    //Animating content (Bug ID: #160)
                    unwrappedController.view.setNeedsLayout()
                    unwrappedController.view.layoutIfNeeded()
                }
 
                
                }) { (animated:Bool) -> Void in}
        } else {  //  If can't get rootViewController then printing warning to user.
            showLog("You must set UIWindow.rootViewController in your AppDelegate to work with IQKeyboardManager")
        }
    }

    /* Adjusting RootViewController's frame according to interface orientation. */
    private func adjustFrame() {
        
        //  We are unable to get textField object while keyboard showing on UIWebView's textField.  (Bug ID: #11)
        if _textFieldView == nil {
            return
        }
        
        let textFieldView = _textFieldView!

        showLog("****** \(#function) %@ started ******")

        //  Boolean to know keyboard is showing/hiding
        _keyboardManagerFlags.isKeyboardShowing = true
        
        //  Getting KeyWindow object.
        let optionalWindow = keyWindow()
        
        //  Getting RootViewController.  (Bug ID: #1, #4)
        var optionalRootController = _textFieldView?.topMostController()
        if optionalRootController == nil {
            optionalRootController = keyWindow()?.topMostController()
        }
        
        //  Converting Rectangle according to window bounds.
        let optionalTextFieldViewRect = textFieldView.superview?.convertRect(textFieldView.frame, toView: optionalWindow)

        if optionalRootController == nil || optionalWindow == nil || optionalTextFieldViewRect == nil {
            return
        }
        
        let rootController = optionalRootController!
        let window = optionalWindow!
        let textFieldViewRect = optionalTextFieldViewRect!
        
        //  Getting RootViewRect.
        var rootViewRect = rootController.view.frame
        //Getting statusBarFrame

        //Maintain keyboardDistanceFromTextField
        var specialKeyboardDistanceFromTextField = textFieldView.keyboardDistanceFromTextField
        
        if textFieldView.isSearchBarTextField() {
            
            if  let searchBar = textFieldView.superviewOfClassType(UISearchBar.self) {
                specialKeyboardDistanceFromTextField = searchBar.keyboardDistanceFromTextField;
            }
        }
        
        let newKeyboardDistanceFromTextField = (specialKeyboardDistanceFromTextField == kIQUseDefaultKeyboardDistance) ? keyboardDistanceFromTextField : specialKeyboardDistanceFromTextField
        var kbSize = _kbSize
        kbSize.height += newKeyboardDistanceFromTextField

        let statusBarFrame = UIApplication.sharedApplication().statusBarFrame
        
        //  (Bug ID: #250)
        var layoutGuidePosition = IQLayoutGuidePosition.None
        
        if let viewController = textFieldView.viewController() {
            
            if let constraint = viewController.IQLayoutGuideConstraint {
                
                var layoutGuide : UILayoutSupport?
                if let itemLayoutGuide = constraint.firstItem as? UILayoutSupport {
                    layoutGuide = itemLayoutGuide
                } else if let itemLayoutGuide = constraint.secondItem as? UILayoutSupport {
                    layoutGuide = itemLayoutGuide
                }
                
                if let itemLayoutGuide : UILayoutSupport = layoutGuide {
                    
                    if (itemLayoutGuide === viewController.topLayoutGuide)    //If topLayoutGuide constraint
                    {
                        layoutGuidePosition = .Top
                    }
                    else if (itemLayoutGuide === viewController.bottomLayoutGuide)    //If bottomLayoutGuice constraint
                    {
                        layoutGuidePosition = .Bottom
                    }
                }
            }
        }
        
        let topLayoutGuide : CGFloat = CGRectGetHeight(statusBarFrame)

        var move : CGFloat = 0.0
        //  Move positive = textField is hidden.
        //  Move negative = textField is showing.
        
        //  Checking if there is bottomLayoutGuide attached (Bug ID: #250)
        if layoutGuidePosition == .Bottom {
            //  Calculating move position.
            move = CGRectGetMaxY(textFieldViewRect)-(CGRectGetHeight(window.frame)-kbSize.height)
        } else {
            //  Calculating move position. Common for both normal and special cases.
            move = min(CGRectGetMinY(textFieldViewRect)-(topLayoutGuide+5), CGRectGetMaxY(textFieldViewRect)-(CGRectGetHeight(window.frame)-kbSize.height))
        }
        
        showLog("Need to move: \(move)")

        var superScrollView : UIScrollView? = nil
        var superView = textFieldView.superviewOfClassType(UIScrollView) as? UIScrollView
        
        //Getting UIScrollView whose scrolling is enabled.    //  (Bug ID: #285)
        while let view = superView {
            
            if (view.scrollEnabled) {
                superScrollView = superView
                break
            }
            else {
                //  Getting it's superScrollView.   //  (Enhancement ID: #21, #24)
                superView = view.superviewOfClassType(UIScrollView) as? UIScrollView
            }
        }
        
        //If there was a lastScrollView.    //  (Bug ID: #34)
        if let lastScrollView = _lastScrollView {
            //If we can't find current superScrollView, then setting lastScrollView to it's original form.
            if superScrollView == nil {
                
                showLog("Restoring \(lastScrollView._IQDescription()) contentInset to : \(_startingContentInsets) and contentOffset to : \(_startingContentOffset)")

                UIView.animateWithDuration(_animationDuration, delay: 0, options: UIViewAnimationOptions.BeginFromCurrentState.union(_animationCurve), animations: { () -> Void in
                    
                    lastScrollView.contentInset = self._startingContentInsets
                    lastScrollView.scrollIndicatorInsets = self._startingScrollIndicatorInsets
                    }) { (animated:Bool) -> Void in }
                
                if lastScrollView.shouldRestoreScrollViewContentOffset == true {
                    lastScrollView.setContentOffset(_startingContentOffset, animated: true)
                }
                
                _startingContentInsets = UIEdgeInsetsZero
                _startingScrollIndicatorInsets = UIEdgeInsetsZero
                _startingContentOffset = CGPointZero
                _lastScrollView = nil
            } else if superScrollView != lastScrollView {     //If both scrollView's are different, then reset lastScrollView to it's original frame and setting current scrollView as last scrollView.
                
                showLog("Restoring \(lastScrollView._IQDescription()) contentInset to : \(_startingContentInsets) and contentOffset to : \(_startingContentOffset)")
                
                UIView.animateWithDuration(_animationDuration, delay: 0, options: UIViewAnimationOptions.BeginFromCurrentState.union(_animationCurve), animations: { () -> Void in
                    
                    lastScrollView.contentInset = self._startingContentInsets
                    lastScrollView.scrollIndicatorInsets = self._startingScrollIndicatorInsets
                    }) { (animated:Bool) -> Void in }
                
                if lastScrollView.shouldRestoreScrollViewContentOffset == true {
                    lastScrollView.setContentOffset(_startingContentOffset, animated: true)
                }

                _lastScrollView = superScrollView
                _startingContentInsets = superScrollView!.contentInset
                _startingScrollIndicatorInsets = superScrollView!.scrollIndicatorInsets
                _startingContentOffset = superScrollView!.contentOffset
                
                showLog("Saving New \(lastScrollView._IQDescription()) contentInset : \(_startingContentInsets) and contentOffset : \(_startingContentOffset)")
            }
            //Else the case where superScrollView == lastScrollView means we are on same scrollView after switching to different textField. So doing nothing, going ahead
        } else if let unwrappedSuperScrollView = superScrollView {    //If there was no lastScrollView and we found a current scrollView. then setting it as lastScrollView.
            _lastScrollView = unwrappedSuperScrollView
            _startingContentInsets = unwrappedSuperScrollView.contentInset
            _startingScrollIndicatorInsets = unwrappedSuperScrollView.scrollIndicatorInsets
            _startingContentOffset = unwrappedSuperScrollView.contentOffset

            showLog("Saving \(unwrappedSuperScrollView._IQDescription()) contentInset : \(_startingContentInsets) and contentOffset : \(_startingContentOffset)")
        }
        
        //  Special case for ScrollView.
        //  If we found lastScrollView then setting it's contentOffset to show textField.
        if let lastScrollView = _lastScrollView {
            //Saving
            var lastView = textFieldView
            var superScrollView = _lastScrollView
            
            while let scrollView = superScrollView {
                
                //Looping in upper hierarchy until we don't found any scrollView in it's upper hirarchy till UIWindow object.
                if move > 0 ? (move > (-scrollView.contentOffset.y - scrollView.contentInset.top)) : scrollView.contentOffset.y>0 {
                    
                    //Getting lastViewRect.
                    if let lastViewRect = lastView.superview?.convertRect(lastView.frame, toView: scrollView) {
                        
                        //Calculating the expected Y offset from move and scrollView's contentOffset.
                        var shouldOffsetY = scrollView.contentOffset.y - min(scrollView.contentOffset.y,-move)
                        
                        //Rearranging the expected Y offset according to the view.
                        shouldOffsetY = min(shouldOffsetY, lastViewRect.origin.y /*-5*/)   //-5 is for good UI.//Commenting -5 (Bug ID: #69)

                        //[_textFieldView isKindOfClass:[UITextView class]] If is a UITextView type
                        //[superScrollView superviewOfClassType:[UIScrollView class]] == nil    If processing scrollView is last scrollView in upper hierarchy (there is no other scrollView upper hierrchy.)
                        //[_textFieldView isKindOfClass:[UITextView class]] If is a UITextView type
                        //shouldOffsetY >= 0     shouldOffsetY must be greater than in order to keep distance from navigationBar (Bug ID: #92)
                        if textFieldView is UITextView == true && scrollView.superviewOfClassType(UIScrollView) == nil && shouldOffsetY >= 0 {
                            var maintainTopLayout : CGFloat = 0
                            
                            if let navigationBarFrame = textFieldView.viewController()?.navigationController?.navigationBar.frame {
                                maintainTopLayout = CGRectGetMaxY(navigationBarFrame)
                            }
                            
                            maintainTopLayout += 10.0 //For good UI
                            
                            //  Converting Rectangle according to window bounds.
                            if let currentTextFieldViewRect = textFieldView.superview?.convertRect(textFieldView.frame, toView: window) {

                                //Calculating expected fix distance which needs to be managed from navigation bar
                                let expectedFixDistance = CGRectGetMinY(currentTextFieldViewRect) - maintainTopLayout
                                
                                //Now if expectedOffsetY (superScrollView.contentOffset.y + expectedFixDistance) is lower than current shouldOffsetY, which means we're in a position where navigationBar up and hide, then reducing shouldOffsetY with expectedOffsetY (superScrollView.contentOffset.y + expectedFixDistance)
                                shouldOffsetY = min(shouldOffsetY, scrollView.contentOffset.y + expectedFixDistance)

                                //Setting move to 0 because now we don't want to move any view anymore (All will be managed by our contentInset logic.
                                move = 0
                            }
                            else {
                                //Subtracting the Y offset from the move variable, because we are going to change scrollView's contentOffset.y to shouldOffsetY.
                                move -= (shouldOffsetY-scrollView.contentOffset.y)
                            }
                        }
                        else
                        {
                            //Subtracting the Y offset from the move variable, because we are going to change scrollView's contentOffset.y to shouldOffsetY.
                            move -= (shouldOffsetY-scrollView.contentOffset.y)
                        }
                        
                        //Getting problem while using `setContentOffset:animated:`, So I used animation API.
                        UIView.animateWithDuration(_animationDuration, delay: 0, options: UIViewAnimationOptions.BeginFromCurrentState.union(_animationCurve), animations: { () -> Void in
                        
                            self.showLog("Adjusting \(scrollView.contentOffset.y-shouldOffsetY) to \(scrollView._IQDescription()) ContentOffset")
                            
                            self.showLog("Remaining Move: \(move)")
                            
                            scrollView.contentOffset = CGPointMake(scrollView.contentOffset.x, shouldOffsetY)
                            }) { (animated:Bool) -> Void in }
                    }
                    
                    //  Getting next lastView & superScrollView.
                    lastView = scrollView
                    superScrollView = lastView.superviewOfClassType(UIScrollView) as? UIScrollView
                } else {
                    break
                }
            }
            
            //Updating contentInset
            if let lastScrollViewRect = lastScrollView.superview?.convertRect(lastScrollView.frame, toView: window) {
                
                let bottom : CGFloat = kbSize.height-keyboardDistanceFromTextField-(CGRectGetHeight(window.frame)-CGRectGetMaxY(lastScrollViewRect))
                
                // Update the insets so that the scroll vew doesn't shift incorrectly when the offset is near the bottom of the scroll view.
                var movedInsets = lastScrollView.contentInset
                
                movedInsets.bottom = max(_startingContentInsets.bottom, bottom)
                
                showLog("\(lastScrollView._IQDescription()) old ContentInset : \(lastScrollView.contentInset)")
                
                //Getting problem while using `setContentOffset:animated:`, So I used animation API.
                UIView.animateWithDuration(_animationDuration, delay: 0, options: UIViewAnimationOptions.BeginFromCurrentState.union(_animationCurve), animations: { () -> Void in
                    lastScrollView.contentInset = movedInsets

                    var newInset = lastScrollView.scrollIndicatorInsets
                    newInset.bottom = movedInsets.bottom
                    lastScrollView.scrollIndicatorInsets = newInset

                    }) { (animated:Bool) -> Void in }

                showLog("\(lastScrollView._IQDescription()) new ContentInset : \(lastScrollView.contentInset)")
            }
        }
        //Going ahead. No else if.
        
        if layoutGuidePosition == .Top {

            let constraint = textFieldView.viewController()!.IQLayoutGuideConstraint!

            let constant = min(_layoutGuideConstraintInitialConstant, constraint.constant-move)
            
            UIView.animateWithDuration(_animationDuration, delay: 0, options: (_animationCurve.union(UIViewAnimationOptions.BeginFromCurrentState)), animations: { () -> Void in
                
                constraint.constant = constant
                self._rootViewController?.view.setNeedsLayout()
                self._rootViewController?.view.layoutIfNeeded()
                
                }, completion: { (finished) -> Void in })

        } else if layoutGuidePosition == .Bottom {
            
            let constraint = textFieldView.viewController()!.IQLayoutGuideConstraint!

            let constant = max(_layoutGuideConstraintInitialConstant, constraint.constant+move)
            
            UIView.animateWithDuration(_animationDuration, delay: 0, options: (_animationCurve.union(UIViewAnimationOptions.BeginFromCurrentState)), animations: { () -> Void in
                
                constraint.constant = constant
                self._rootViewController?.view.setNeedsLayout()
                self._rootViewController?.view.layoutIfNeeded()
                
                }, completion: { (finished) -> Void in })

        } else {
            
            //Special case for UITextView(Readjusting textView.contentInset when textView hight is too big to fit on screen)
            //_lastScrollView       If not having inside any scrollView, (now contentInset manages the full screen textView.
            //[_textFieldView isKindOfClass:[UITextView class]] If is a UITextView type
            if let textView = textFieldView as? UITextView {
                let textViewHeight = min(CGRectGetHeight(textView.frame), (CGRectGetHeight(window.frame)-kbSize.height-(topLayoutGuide)))
                
                if (textView.frame.size.height-textView.contentInset.bottom>textViewHeight)
                {
                    UIView.animateWithDuration(_animationDuration, delay: 0, options: (_animationCurve.union(UIViewAnimationOptions.BeginFromCurrentState)), animations: { () -> Void in
                        
                        self.showLog("\(textFieldView._IQDescription()) Old UITextView.contentInset : \(textView.contentInset)")
                        
                        //_isTextViewContentInsetChanged,  If frame is not change by library in past, then saving user textView properties  (Bug ID: #92)
                        if (self.isTextViewContentInsetChanged == false)
                        {
                            self.startingTextViewContentInsets = textView.contentInset
                            self.startingTextViewScrollIndicatorInsets = textView.scrollIndicatorInsets
                        }
                        
                        var newContentInset = textView.contentInset
                        newContentInset.bottom = textView.frame.size.height-textViewHeight
                        textView.contentInset = newContentInset
                        textView.scrollIndicatorInsets = newContentInset
                        self.isTextViewContentInsetChanged = true
                        
                        self.showLog("\(textFieldView._IQDescription()) Old UITextView.contentInset : \(textView.contentInset)")
                        
                        
                        }, completion: { (finished) -> Void in })
                }
            }

            //  Special case for iPad modalPresentationStyle.
            if rootController.modalPresentationStyle == UIModalPresentationStyle.FormSheet || rootController.modalPresentationStyle == UIModalPresentationStyle.PageSheet {
                
                showLog("Found Special case for Model Presentation Style: \(rootController.modalPresentationStyle)")
                
                //  +Positive or zero.
                if move >= 0 {
                    // We should only manipulate y.
                    rootViewRect.origin.y -= move
                    
                    //  From now prevent keyboard manager to slide up the rootView to more than keyboard height. (Bug ID: #93)
                    if preventShowingBottomBlankSpace == true {
                        let minimumY: CGFloat = (CGRectGetHeight(window.frame)-rootViewRect.size.height-topLayoutGuide)/2-(kbSize.height-newKeyboardDistanceFromTextField)
                        
                        rootViewRect.origin.y = max(CGRectGetMinY(rootViewRect), minimumY)
                    }
                    
                    showLog("Moving Upward")
                    //  Setting adjusted rootViewRect
                    setRootViewFrame(rootViewRect)
                } else {  //  -Negative
                    //  Calculating disturbed distance. Pull Request #3
                    let disturbDistance = CGRectGetMinY(rootViewRect)-CGRectGetMinY(_topViewBeginRect)
                    
                    //  disturbDistance Negative = frame disturbed.
                    //  disturbDistance positive = frame not disturbed.
                    if disturbDistance < 0 {
                        // We should only manipulate y.
                        rootViewRect.origin.y -= max(move, disturbDistance)
                        
                        showLog("Moving Downward")
                        //  Setting adjusted rootViewRect
                        setRootViewFrame(rootViewRect)
                    }
                }
            } else {  //If presentation style is neither UIModalPresentationFormSheet nor UIModalPresentationPageSheet then going ahead.(General case)
                //  +Positive or zero.
                if move >= 0 {
                    
                    rootViewRect.origin.y -= move

                    //  From now prevent keyboard manager to slide up the rootView to more than keyboard height. (Bug ID: #93)
                    if preventShowingBottomBlankSpace == true {
                        
                        rootViewRect.origin.y = max(rootViewRect.origin.y, min(0, -kbSize.height+newKeyboardDistanceFromTextField))
                    }
                    
                    showLog("Moving Upward")
                    //  Setting adjusted rootViewRect
                    setRootViewFrame(rootViewRect)
                } else {  //  -Negative
                    let disturbDistance : CGFloat = CGRectGetMinY(rootViewRect)-CGRectGetMinY(_topViewBeginRect)
                    
                    //  disturbDistance Negative = frame disturbed.
                    //  disturbDistance positive = frame not disturbed.
                    if disturbDistance < 0 {
                        
                        rootViewRect.origin.y -= max(move, disturbDistance)
                        
                        showLog("Moving Downward")
                        //  Setting adjusted rootViewRect
                        //  Setting adjusted rootViewRect
                        setRootViewFrame(rootViewRect)
                    }
                }
            }
        }

        showLog("****** \(#function) ended ******")
    }

    ///---------------------
    /// MARK: Public Methods
    ///---------------------
    
    /*  Refreshes textField/textView position if any external changes is explicitly made by user.   */
    public func reloadLayoutIfNeeded() -> Void {

        if privateIsEnabled() == false {
            return
        }

        if _textFieldView != nil &&
        _keyboardManagerFlags.isKeyboardShowing == true &&
        CGRectEqualToRect(_topViewBeginRect, CGRectZero) == false &&
        _textFieldView?.isAlertViewTextField() == false {
            adjustFrame()
        }
    }

    ///-------------------------------
    /// MARK: UIKeyboard Notifications
    ///-------------------------------

    /*  UIKeyboardWillShowNotification. */
    internal func keyboardWillShow(notification : NSNotification?) -> Void {
        
        _kbShowNotification = notification

        if privateIsEnabled() == false {
            return
        }
        
        showLog("****** \(#function) started ******")

        //  (Bug ID: #5)
        if CGRectEqualToRect(_topViewBeginRect, CGRectZero) == true {
            //  keyboard is not showing(At the beginning only). We should save rootViewRect.
            _rootViewController = _textFieldView?.topMostController()
            if _rootViewController == nil {
                _rootViewController = keyWindow()?.topMostController()
            }
            
            if let unwrappedRootController = _rootViewController {
                _topViewBeginRect = unwrappedRootController.view.frame
                
                if shouldFixInteractivePopGestureRecognizer == true && unwrappedRootController is UINavigationController {
                    _topViewBeginRect.origin = CGPointZero;
                }

                showLog("Saving \(unwrappedRootController._IQDescription()) beginning Frame: \(_topViewBeginRect)")
            } else {
                _topViewBeginRect = CGRectZero
            }
        }

        let oldKBSize = _kbSize

        if let info = notification?.userInfo {
            
            //  Getting keyboard animation.
            if let curve = info[UIKeyboardAnimationCurveUserInfoKey]?.unsignedLongValue {
                _animationCurve = UIViewAnimationOptions(rawValue: curve)
            } else {
                _animationCurve = UIViewAnimationOptions.CurveEaseOut
            }
            
            //  Getting keyboard animation duration
            if let duration = info[UIKeyboardAnimationDurationUserInfoKey]?.doubleValue {
                
                //Saving animation duration
                if duration != 0.0 {
                    _animationDuration = duration
                }
            } else {
                _animationDuration = 0.25
            }
            
            //  Getting UIKeyboardSize.
            if let kbFrame = info[UIKeyboardFrameEndUserInfoKey]?.CGRectValue {
                
                let screenSize = UIScreen.mainScreen().bounds
                
                //Calculating actual keyboard displayed size, keyboard frame may be different when hardware keyboard is attached (Bug ID: #469) (Bug ID: #381)
                let intersectRect = CGRectIntersection(kbFrame, screenSize)
                
                if CGRectIsNull(intersectRect) {
                    _kbSize = CGSizeMake(screenSize.size.width, 0)
                } else {
                    _kbSize = intersectRect.size
                }

                showLog("UIKeyboard Size : \(_kbSize)")
            }
        }
        
        //  Getting topMost ViewController.
        var topMostController = _textFieldView?.topMostController()
        
        if topMostController == nil {
            topMostController = keyWindow()?.topMostController()
        }

        //If last restored keyboard size is different(any orientation accure), then refresh. otherwise not.
        if CGSizeEqualToSize(_kbSize, oldKBSize) == false {
            
            //If _textFieldView is inside UITableViewController then let UITableViewController to handle it (Bug ID: #37) (Bug ID: #76) See note:- https://developer.apple.com/library/ios/documentation/StringsTextFonts/Conceptual/TextAndWebiPhoneOS/KeyboardManagement/KeyboardManagement.html If it is UIAlertView textField then do not affect anything (Bug ID: #70).
            
            if _textFieldView != nil && _textFieldView?.isAlertViewTextField() == false {
                
                //Getting textField viewController
                if _textFieldView?.viewController() != nil {
                    
                    //  keyboard is already showing. adjust frame.
                    adjustFrame()
                }
            }
        }
        
        showLog("****** \(#function) ended ******")
    }

    /*  UIKeyboardDidShowNotification. */
    internal func keyboardDidShow(notification : NSNotification?) -> Void {
        
        if privateIsEnabled() == false {
            return
        }
        
        showLog("****** \(#function) started ******")
        
        //  Getting topMost ViewController.
        var topMostController = _textFieldView?.topMostController()
        
        if topMostController == nil {
            topMostController = keyWindow()?.topMostController()
        }
        
        if _textFieldView != nil && topMostController?.modalPresentationStyle == UIModalPresentationStyle.FormSheet && _textFieldView?.isAlertViewTextField() == false {
            
            //  keyboard is already showing. adjust frame.
            adjustFrame()
        }
        
        showLog("****** \(#function) ended ******")
    }

    /*  UIKeyboardWillHideNotification. So setting rootViewController to it's default frame. */
    internal func keyboardWillHide(notification : NSNotification?) -> Void {
        
        //If it's not a fake notification generated by [self setEnable:NO].
        if notification != nil {
            _kbShowNotification = nil
        }
        
        //If not enabled then do nothing.
        if privateIsEnabled() == false {
            return
        }
        
        showLog("****** \(#function) started ******")

        //Commented due to #56. Added all the conditions below to handle UIWebView's textFields.    (Bug ID: #56)
        //  We are unable to get textField object while keyboard showing on UIWebView's textField.  (Bug ID: #11)
        //    if (_textFieldView == nil)   return

        //  Boolean to know keyboard is showing/hiding
        _keyboardManagerFlags.isKeyboardShowing = false
        
        let info : [NSObject : AnyObject]? = notification?.userInfo
        
        //  Getting keyboard animation duration
        if let duration =  info?[UIKeyboardAnimationDurationUserInfoKey]?.doubleValue {
            if duration != 0 {
                //  Setitng keyboard animation duration
                _animationDuration = duration
            }
        }
        
        //Restoring the contentOffset of the lastScrollView
        if let lastScrollView = _lastScrollView {
            
            UIView.animateWithDuration(_animationDuration, delay: 0, options: UIViewAnimationOptions.BeginFromCurrentState.union(_animationCurve), animations: { () -> Void in
                
                lastScrollView.contentInset = self._startingContentInsets
                lastScrollView.scrollIndicatorInsets = self._startingScrollIndicatorInsets
                
                if lastScrollView.shouldRestoreScrollViewContentOffset == true {
                    lastScrollView.contentOffset = self._startingContentOffset
                }
                
                self.showLog("Restoring \(lastScrollView._IQDescription()) contentInset to : \(self._startingContentInsets) and contentOffset to : \(self._startingContentOffset)")

                // TODO: restore scrollView state
                // This is temporary solution. Have to implement the save and restore scrollView state
                var superScrollView : UIScrollView? = lastScrollView

                while let scrollView = superScrollView {

                    let contentSize = CGSizeMake(max(scrollView.contentSize.width, CGRectGetWidth(scrollView.frame)), max(scrollView.contentSize.height, CGRectGetHeight(scrollView.frame)))
                    
                    let minimumY = contentSize.height - CGRectGetHeight(scrollView.frame)
                    
                    if minimumY < scrollView.contentOffset.y {
                        scrollView.contentOffset = CGPointMake(scrollView.contentOffset.x, minimumY)
                        
                        self.showLog("Restoring \(scrollView._IQDescription()) contentOffset to : \(self._startingContentOffset)")
                    }
                    
                    superScrollView = scrollView.superviewOfClassType(UIScrollView) as? UIScrollView
                }
                }) { (finished) -> Void in }
        }
        
        //  Setting rootViewController frame to it's original position. //  (Bug ID: #18)
        if CGRectEqualToRect(_topViewBeginRect, CGRectZero) == false {
            
            if let rootViewController = _rootViewController {
                
                //frame size needs to be adjusted on iOS8 due to orientation API changes.
                _topViewBeginRect.size = rootViewController.view.frame.size
                
                //Used UIViewAnimationOptionBeginFromCurrentState to minimize strange animations.
                UIView.animateWithDuration(_animationDuration, delay: 0, options: UIViewAnimationOptions.BeginFromCurrentState.union(_animationCurve), animations: { () -> Void in
                    
                    var hasDoneTweakLayoutGuide = false
                    
                    if let viewController = self._textFieldView?.viewController() {
                        
                        if let constraint = viewController.IQLayoutGuideConstraint {
                            
                            var layoutGuide : UILayoutSupport?
                            if let itemLayoutGuide = constraint.firstItem as? UILayoutSupport {
                                layoutGuide = itemLayoutGuide
                            } else if let itemLayoutGuide = constraint.secondItem as? UILayoutSupport {
                                layoutGuide = itemLayoutGuide
                            }
                            
                            if let itemLayoutGuide : UILayoutSupport = layoutGuide {
                                
                                if (itemLayoutGuide === viewController.topLayoutGuide || itemLayoutGuide === viewController.bottomLayoutGuide)
                                {
                                    constraint.constant = self._layoutGuideConstraintInitialConstant
                                    rootViewController.view.setNeedsLayout()
                                    rootViewController.view.layoutIfNeeded()

                                    hasDoneTweakLayoutGuide = true
                                }
                            }
                        }
                    }
                    
                    if hasDoneTweakLayoutGuide == false {
                        self.showLog("Restoring \(rootViewController._IQDescription()) frame to : \(self._topViewBeginRect)")
                        
                        //  Setting it's new frame
                        rootViewController.view.frame = self._topViewBeginRect
                        
                        //Animating content if needed (Bug ID: #204)
                        if self.layoutIfNeededOnUpdate == true {
                            //Animating content (Bug ID: #160)
                            rootViewController.view.setNeedsLayout()
                            rootViewController.view.layoutIfNeeded()
                        }
                    }
                    }) { (finished) -> Void in }
                
                _rootViewController = nil
            }
        }
        
        //Reset all values
        _lastScrollView = nil
        _kbSize = CGSizeZero
        _startingContentInsets = UIEdgeInsetsZero
        _startingScrollIndicatorInsets = UIEdgeInsetsZero
        _startingContentOffset = CGPointZero
        //    topViewBeginRect = CGRectZero    //Commented due to #82

        showLog("****** \(#function) ended ******")
    }

    internal func keyboardDidHide(notification:NSNotification) {

        showLog("****** \(#function) started ******")
        
        _topViewBeginRect = CGRectZero

        showLog("****** \(#function) ended ******")
    }
    
    ///-------------------------------------------
    /// MARK: UITextField/UITextView Notifications
    ///-------------------------------------------

    /**  UITextFieldTextDidBeginEditingNotification, UITextViewTextDidBeginEditingNotification. Fetching UITextFieldView object. */
    internal func textFieldViewDidBeginEditing(notification:NSNotification) {

        showLog("****** \(#function) started ******")

        //  Getting object
        _textFieldView = notification.object as? UIView
        
        if overrideKeyboardAppearance == true {
            
            if let textFieldView = _textFieldView as? UITextField {
                //If keyboard appearance is not like the provided appearance
                if textFieldView.keyboardAppearance != keyboardAppearance {
                    //Setting textField keyboard appearance and reloading inputViews.
                    textFieldView.keyboardAppearance = keyboardAppearance
                    textFieldView.reloadInputViews()
                }
            } else if  let textFieldView = _textFieldView as? UITextView {
                //If keyboard appearance is not like the provided appearance
                if textFieldView.keyboardAppearance != keyboardAppearance {
                    //Setting textField keyboard appearance and reloading inputViews.
                    textFieldView.keyboardAppearance = keyboardAppearance
                    textFieldView.reloadInputViews()
                }
            }
        }
        
        //If autoToolbar enable, then add toolbar on all the UITextField/UITextView's if required.
        if privateIsEnableAutoToolbar() == true {

            showLog("adding UIToolbars if required")

            //UITextView special case. Keyboard Notification is firing before textView notification so we need to resign it first and then again set it as first responder to add toolbar on it.
            if _textFieldView is UITextView == true && _textFieldView?.inputAccessoryView == nil {
                
                UIView.animateWithDuration(0.00001, delay: 0, options: UIViewAnimationOptions.BeginFromCurrentState.union(_animationCurve), animations: { () -> Void in

                    self.addToolbarIfRequired()
                    
                    }, completion: { (finished) -> Void in

                        //On textView toolbar didn't appear on first time, so forcing textView to reload it's inputViews.
                        self._textFieldView?.reloadInputViews()
                })
            } else {
                //Adding toolbar
                addToolbarIfRequired()
            }
        } else {
            removeToolbarIfRequired()
        }

        if privateIsEnabled() == false {
            showLog("****** \(#function) ended ******")
            return
        }
        
        _textFieldView?.window?.addGestureRecognizer(_tapGesture)    //   (Enhancement ID: #14)

        if _keyboardManagerFlags.isKeyboardShowing == false {    //  (Bug ID: #5)

            //  keyboard is not showing(At the beginning only). We should save rootViewRect.
            if let constant = _textFieldView?.viewController()?.IQLayoutGuideConstraint?.constant {
                _layoutGuideConstraintInitialConstant = constant
            }

            _rootViewController = _textFieldView?.topMostController()
            if _rootViewController == nil {
                _rootViewController = keyWindow()?.topMostController()
            }

            if let rootViewController = _rootViewController {
                
                _topViewBeginRect = rootViewController.view.frame
                
                if shouldFixInteractivePopGestureRecognizer == true && rootViewController is UINavigationController {
                    _topViewBeginRect.origin = CGPointZero;
                }

                showLog("Saving \(rootViewController._IQDescription()) beginning frame : \(_topViewBeginRect)")
            }
        }
        
        //If _textFieldView is inside ignored responder then do nothing. (Bug ID: #37, #74, #76)
        //See notes:- https://developer.apple.com/library/ios/documentation/StringsTextFonts/Conceptual/TextAndWebiPhoneOS/KeyboardManagement/KeyboardManagement.html If it is UIAlertView textField then do not affect anything (Bug ID: #70).
        if _textFieldView != nil && _textFieldView?.isAlertViewTextField() == false {

            //  keyboard is already showing. adjust frame.
            adjustFrame()
        }

        showLog("****** \(#function) ended ******")
    }
    
    /**  UITextFieldTextDidEndEditingNotification, UITextViewTextDidEndEditingNotification. Removing fetched object. */
    internal func textFieldViewDidEndEditing(notification:NSNotification) {
        
        showLog("****** \(#function) started ******")

        //Removing gesture recognizer   (Enhancement ID: #14)
        _textFieldView?.window?.removeGestureRecognizer(_tapGesture)
        
        // We check if there's a change in original frame or not.
        
        if let textView = _textFieldView as? UITextView {

            if isTextViewContentInsetChanged == true {
                
                UIView.animateWithDuration(_animationDuration, delay: 0, options: UIViewAnimationOptions.BeginFromCurrentState.union(_animationCurve), animations: { () -> Void in
                    
                    self.isTextViewContentInsetChanged = false
                    
                    self.showLog("Restoring \(textView._IQDescription()) textView.contentInset to : \(self.startingTextViewContentInsets)")
                    
                    //Setting textField to it's initial contentInset
                    textView.contentInset = self.startingTextViewContentInsets
                    textView.scrollIndicatorInsets = self.startingTextViewScrollIndicatorInsets

                    }, completion: { (finished) -> Void in })
            }
        }
        
        //Setting object to nil
        _textFieldView = nil

        showLog("****** \(#function) ended ******")
    }

    ///------------------------------------------
    /// MARK: Interface Orientation Notifications
    ///------------------------------------------
    
    /**  UIApplicationWillChangeStatusBarOrientationNotification. Need to set the textView to it's original position. If any frame changes made. (Bug ID: #92)*/
    internal func willChangeStatusBarOrientation(notification:NSNotification) {
        
        showLog("****** \(#function) started ******")
        
        //If textViewContentInsetChanged is saved then restore it.
        if let textView = _textFieldView as? UITextView {
            
            if isTextViewContentInsetChanged == true {
                
                UIView.animateWithDuration(_animationDuration, delay: 0, options: UIViewAnimationOptions.BeginFromCurrentState.union(_animationCurve), animations: { () -> Void in
                    
                    self.isTextViewContentInsetChanged = false
                    
                    self.showLog("Restoring \(textView._IQDescription()) textView.contentInset to : \(self.startingTextViewContentInsets)")
                    
                    //Setting textField to it's initial contentInset
                    textView.contentInset = self.startingTextViewContentInsets
                    textView.scrollIndicatorInsets = self.startingTextViewScrollIndicatorInsets
                    
                    }, completion: { (finished) -> Void in })
            }
        }

        showLog("****** \(#function) ended ******")
    }
    
    ///------------------
    /// MARK: AutoToolbar
    ///------------------
    
    /**	Get all UITextField/UITextView siblings of textFieldView. */
    private func responderViews()-> [UIView]? {
        
        var superConsideredView : UIView?

        //If find any consider responderView in it's upper hierarchy then will get deepResponderView.
        for disabledClass in toolbarPreviousNextAllowedClasses {
            
            superConsideredView = _textFieldView?.superviewOfClassType(disabledClass)
            
            if superConsideredView != nil {
                break
            }
        }
    
    //If there is a superConsideredView in view's hierarchy, then fetching all it's subview that responds. No sorting for superConsideredView, it's by subView position.    (Enhancement ID: #22)
        if superConsideredView != nil {
            return superConsideredView?.deepResponderViews()
        } else {  //Otherwise fetching all the siblings
            
            if let textFields = _textFieldView?.responderSiblings() {
                
                //Sorting textFields according to behaviour
                switch toolbarManageBehaviour {
                    //If autoToolbar behaviour is bySubviews, then returning it.
                case IQAutoToolbarManageBehaviour.BySubviews:   return textFields
                    
                    //If autoToolbar behaviour is by tag, then sorting it according to tag property.
                case IQAutoToolbarManageBehaviour.ByTag:    return textFields.sortedArrayByTag()
                    
                    //If autoToolbar behaviour is by tag, then sorting it according to tag property.
                case IQAutoToolbarManageBehaviour.ByPosition:    return textFields.sortedArrayByPosition()
                }
            } else {
                return nil
            }
        }
    }
    
    /** Add toolbar if it is required to add on textFields and it's siblings. */
    private func addToolbarIfRequired() {
        
        //	Getting all the sibling textFields.
        if let siblings = responderViews() {
            
            //	If only one object is found, then adding only Done button.
            if siblings.count == 1 || shouldHidePreviousNext == true {
                
                if let textField = _textFieldView {
                    //Either there is no inputAccessoryView or if accessoryView is not appropriate for current situation(There is Previous/Next/Done toolbar).
                    //setInputAccessoryView: check   (Bug ID: #307)
                    if textField.respondsToSelector(Selector("setInputAccessoryView:")) {
                        
                        if textField.inputAccessoryView == nil || textField.inputAccessoryView?.tag == IQKeyboardManager.kIQPreviousNextButtonToolbarTag {
                            //Supporting Custom Done button image (Enhancement ID: #366)
                            if let doneBarButtonItemImage = toolbarDoneBarButtonItemImage {
                                textField.addRightButtonOnKeyboardWithImage(doneBarButtonItemImage, target: self, action: #selector(self.doneAction(_:)), shouldShowPlaceholder: shouldShowTextFieldPlaceholder)
                            }
                                //Supporting Custom Done button text (Enhancement ID: #209, #411, Bug ID: #376)
                            else if let doneBarButtonItemText = toolbarDoneBarButtonItemText {
                                textField.addRightButtonOnKeyboardWithText(doneBarButtonItemText, target: self, action: #selector(self.doneAction(_:)), shouldShowPlaceholder: shouldShowTextFieldPlaceholder)
                            } else {
                                //Now adding textField placeholder text as title of IQToolbar  (Enhancement ID: #27)
                                textField.addDoneOnKeyboardWithTarget(self, action: #selector(self.doneAction(_:)), shouldShowPlaceholder: shouldShowTextFieldPlaceholder)
                            }
                        }
                        else if let toolbar = textField.inputAccessoryView as? IQToolbar {
                            
                            if textField.inputAccessoryView?.tag == IQKeyboardManager.kIQDoneButtonToolbarTag {
                                if let doneBarButtonItemImage = toolbarDoneBarButtonItemImage {
                                    if toolbar.doneImage?.isEqual(doneBarButtonItemImage) == false {
                                        textField.addRightButtonOnKeyboardWithImage(doneBarButtonItemImage, target: self, action: #selector(self.doneAction(_:)), shouldShowPlaceholder: shouldShowTextFieldPlaceholder)
                                    }
                                }
                                    //Supporting Custom Done button text (Enhancement ID: #209, #411, Bug ID: #376)
                                else if let doneBarButtonItemText = toolbarDoneBarButtonItemText {
                                    if toolbar.doneTitle != doneBarButtonItemText {
                                        textField.addRightButtonOnKeyboardWithText(doneBarButtonItemText, target: self, action: #selector(self.doneAction(_:)), shouldShowPlaceholder: shouldShowTextFieldPlaceholder)
                                    }
                                } else if (toolbarDoneBarButtonItemText == nil && toolbar.doneTitle != nil) ||
                                    (toolbarDoneBarButtonItemImage == nil && toolbar.doneImage != nil) {
                                    //Now adding textField placeholder text as title of IQToolbar  (Enhancement ID: #27)
                                    textField.addDoneOnKeyboardWithTarget(self, action: #selector(self.doneAction(_:)), shouldShowPlaceholder: shouldShowTextFieldPlaceholder)
                                }
                            }
                        }
                        
                        textField.inputAccessoryView?.tag = IQKeyboardManager.kIQDoneButtonToolbarTag //  (Bug ID: #78)
                    }
                    
                    if textField.inputAccessoryView is IQToolbar && textField.inputAccessoryView?.tag == IQKeyboardManager.kIQDoneButtonToolbarTag {
                        
                        let toolbar = textField.inputAccessoryView as! IQToolbar
                        
                        //  Setting toolbar to keyboard.
                        if let _textField = textField as? UITextField {
                            
                            //Bar style according to keyboard appearance
                            switch _textField.keyboardAppearance {
                                
                            case UIKeyboardAppearance.Dark:
                                toolbar.barStyle = UIBarStyle.Black
                                toolbar.tintColor = UIColor.whiteColor()
                            default:
                                toolbar.barStyle = UIBarStyle.Default
                                
                                //Setting toolbar tintColor //  (Enhancement ID: #30)
                                if shouldToolbarUsesTextFieldTintColor {
                                    toolbar.tintColor = _textField.tintColor
                                } else if let tintColor = toolbarTintColor {
                                    toolbar.tintColor = tintColor
                                } else {
                                    toolbar.tintColor = UIColor.blackColor()
                                }
                            }
                        } else if let _textView = textField as? UITextView {
                            
                            //Bar style according to keyboard appearance
                            switch _textView.keyboardAppearance {
                                
                            case UIKeyboardAppearance.Dark:
                                toolbar.barStyle = UIBarStyle.Black
                                toolbar.tintColor = UIColor.whiteColor()
                            default:
                                toolbar.barStyle = UIBarStyle.Default
                                
                                if shouldToolbarUsesTextFieldTintColor {
                                    toolbar.tintColor = _textView.tintColor
                                } else if let tintColor = toolbarTintColor {
                                    toolbar.tintColor = tintColor
                                } else {
                                    toolbar.tintColor = UIColor.blackColor()
                                }
                            }
                        }
                        
                        //Setting toolbar title font.   //  (Enhancement ID: #30)
                        if shouldShowTextFieldPlaceholder == true && textField.shouldHideTitle == false {
                            
                            //Updating placeholder font to toolbar.     //(Bug ID: #148, #272)
                            if toolbar.title == nil || toolbar.title != textField.drawingPlaceholderText {
                                toolbar.title = textField.drawingPlaceholderText
                            }
                            
                            //Setting toolbar title font.   //  (Enhancement ID: #30)
                            if placeholderFont != nil {
                                toolbar.titleFont = placeholderFont
                            }
                        } else {
                            
                            toolbar.title = nil
                        }
                    }
                    //Either there is no inputAccessoryView or if accessoryView is not appropriate for current situation(There is Previous/Next/Done toolbar).
                    //setInputAccessoryView: check   (Bug ID: #307)
                    if textField.respondsToSelector(Selector("setInputAccessoryView:")) {
                        
                        if textField.inputAccessoryView == nil || textField.inputAccessoryView?.tag == IQKeyboardManager.kIQPreviousNextButtonToolbarTag {
                            //Supporting Custom Done button image (Enhancement ID: #366)
                            if let doneBarButtonItemImage = toolbarDoneBarButtonItemImage {
                                textField.addRightButtonOnKeyboardWithImage(doneBarButtonItemImage, target: self, action: #selector(self.doneAction(_:)), shouldShowPlaceholder: shouldShowTextFieldPlaceholder)
                            }
                                //Supporting Custom Done button text (Enhancement ID: #209, #411, Bug ID: #376)
                            else if let doneBarButtonItemText = toolbarDoneBarButtonItemText {
                                textField.addRightButtonOnKeyboardWithText(doneBarButtonItemText, target: self, action: #selector(self.doneAction(_:)), shouldShowPlaceholder: shouldShowTextFieldPlaceholder)
                            } else {
                                //Now adding textField placeholder text as title of IQToolbar  (Enhancement ID: #27)
                                textField.addDoneOnKeyboardWithTarget(self, action: #selector(self.doneAction(_:)), shouldShowPlaceholder: shouldShowTextFieldPlaceholder)
                            }
                        }
                        else if let toolbar = textField.inputAccessoryView as? IQToolbar {
                            
                            if textField.inputAccessoryView?.tag == IQKeyboardManager.kIQDoneButtonToolbarTag {
                                if let doneBarButtonItemImage = toolbarDoneBarButtonItemImage {
                                    if toolbar.doneImage?.isEqual(doneBarButtonItemImage) == false {
                                        textField.addRightButtonOnKeyboardWithImage(doneBarButtonItemImage, target: self, action: #selector(self.doneAction(_:)), shouldShowPlaceholder: shouldShowTextFieldPlaceholder)
                                    }
                                }
                                    //Supporting Custom Done button text (Enhancement ID: #209, #411, Bug ID: #376)
                                else if let doneBarButtonItemText = toolbarDoneBarButtonItemText {
                                    if toolbar.doneTitle != doneBarButtonItemText {
                                        textField.addRightButtonOnKeyboardWithText(doneBarButtonItemText, target: self, action: #selector(self.doneAction(_:)), shouldShowPlaceholder: shouldShowTextFieldPlaceholder)
                                    }
                                } else if (toolbarDoneBarButtonItemText == nil && toolbar.doneTitle != nil) ||
                                    (toolbarDoneBarButtonItemImage == nil && toolbar.doneImage != nil) {
                                    //Now adding textField placeholder text as title of IQToolbar  (Enhancement ID: #27)
                                    textField.addDoneOnKeyboardWithTarget(self, action: #selector(self.doneAction(_:)), shouldShowPlaceholder: shouldShowTextFieldPlaceholder)
                                }
                            }
                        }
                        
                        textField.inputAccessoryView?.tag = IQKeyboardManager.kIQDoneButtonToolbarTag //  (Bug ID: #78)
                    }
                    
                    if textField.inputAccessoryView is IQToolbar && textField.inputAccessoryView?.tag == IQKeyboardManager.kIQDoneButtonToolbarTag {
                        
                        let toolbar = textField.inputAccessoryView as! IQToolbar
                        
                        //  Setting toolbar to keyboard.
                        if let _textField = textField as? UITextField {
                            
                            //Bar style according to keyboard appearance
                            switch _textField.keyboardAppearance {
                                
                            case UIKeyboardAppearance.Dark:
                                toolbar.barStyle = UIBarStyle.Black
                                toolbar.tintColor = UIColor.whiteColor()
                            default:
                                toolbar.barStyle = UIBarStyle.Default
                                
                                //Setting toolbar tintColor //  (Enhancement ID: #30)
                                if shouldToolbarUsesTextFieldTintColor {
                                    toolbar.tintColor = _textField.tintColor
                                } else if let tintColor = toolbarTintColor {
                                    toolbar.tintColor = tintColor
                                } else {
                                    toolbar.tintColor = UIColor.blackColor()
                                }
                            }
                        } else if let _textView = textField as? UITextView {
                            
                            //Bar style according to keyboard appearance
                            switch _textView.keyboardAppearance {
                                
                            case UIKeyboardAppearance.Dark:
                                toolbar.barStyle = UIBarStyle.Black
                                toolbar.tintColor = UIColor.whiteColor()
                            default:
                                toolbar.barStyle = UIBarStyle.Default
                                
                                if shouldToolbarUsesTextFieldTintColor {
                                    toolbar.tintColor = _textView.tintColor
                                } else if let tintColor = toolbarTintColor {
                                    toolbar.tintColor = tintColor
                                } else {
                                    toolbar.tintColor = UIColor.blackColor()
                                }
                            }
                        }
                        
                        //Setting toolbar title font.   //  (Enhancement ID: #30)
                        if shouldShowTextFieldPlaceholder == true && textField.shouldHideTitle == false {
                            
                            //Updating placeholder font to toolbar.     //(Bug ID: #148, #272)
                            if toolbar.title == nil || toolbar.title != textField.drawingPlaceholderText {
                                toolbar.title = textField.drawingPlaceholderText
                            }
                            
                            //Setting toolbar title font.   //  (Enhancement ID: #30)
                            if placeholderFont != nil {
                                toolbar.titleFont = placeholderFont
                            }
                        } else {
                            
                            toolbar.title = nil
                        }
                    }
                }
            } else if siblings.count != 0 {
                
                //	If more than 1 textField is found. then adding previous/next/done buttons on it.
                for textField in siblings {
                    
                    //Either there is no inputAccessoryView or if accessoryView is not appropriate for current situation(There is Done toolbar).
                    //setInputAccessoryView: check   (Bug ID: #307)
                    if textField.respondsToSelector(Selector("setInputAccessoryView:")) && (textField.inputAccessoryView == nil || textField.inputAccessoryView?.tag == IQKeyboardManager.kIQDoneButtonToolbarTag) {
                        
                        if textField.inputAccessoryView == nil || textField.inputAccessoryView?.tag == IQKeyboardManager.kIQDoneButtonToolbarTag {
                            //Supporting Custom Done button image (Enhancement ID: #366)
                            if let doneBarButtonItemImage = toolbarDoneBarButtonItemImage {
                                textField.addPreviousNextRightOnKeyboardWithTarget(self, rightButtonImage: doneBarButtonItemImage, previousAction: #selector(self.previousAction(_:)), nextAction: #selector(self.nextAction(_:)), rightButtonAction: #selector(self.doneAction(_:)), shouldShowPlaceholder: shouldShowTextFieldPlaceholder)
                            }
                                //Supporting Custom Done button text (Enhancement ID: #209, #411, Bug ID: #376)
                            else if let doneBarButtonItemText = toolbarDoneBarButtonItemText {
                                textField.addPreviousNextRightOnKeyboardWithTarget(self, rightButtonTitle: doneBarButtonItemText, previousAction: #selector(self.previousAction(_:)), nextAction: #selector(self.nextAction(_:)), rightButtonAction: #selector(self.doneAction(_:)), shouldShowPlaceholder: shouldShowTextFieldPlaceholder)
                            } else {
                                //Now adding textField placeholder text as title of IQToolbar  (Enhancement ID: #27)
                                textField.addPreviousNextDoneOnKeyboardWithTarget(self, previousAction: #selector(self.previousAction(_:)), nextAction: #selector(self.nextAction(_:)), doneAction: #selector(self.doneAction(_:)), shouldShowPlaceholder: shouldShowTextFieldPlaceholder)
                            }
                        }
                        else if let toolbar = textField.inputAccessoryView as? IQToolbar {
                            
                            if textField.inputAccessoryView?.tag == IQKeyboardManager.kIQPreviousNextButtonToolbarTag {
                                if let doneBarButtonItemImage = toolbarDoneBarButtonItemImage {
                                    if toolbar.doneImage?.isEqual(doneBarButtonItemImage) == false {
                                        textField.addPreviousNextRightOnKeyboardWithTarget(self, rightButtonImage: toolbarDoneBarButtonItemImage!, previousAction: #selector(self.previousAction(_:)), nextAction: #selector(self.nextAction(_:)), rightButtonAction: #selector(self.doneAction(_:)), shouldShowPlaceholder: shouldShowTextFieldPlaceholder)
                                    }
                                }
                                    //Supporting Custom Done button text (Enhancement ID: #209, #411, Bug ID: #376)
                                else if let doneBarButtonItemText = toolbarDoneBarButtonItemText {
                                    if toolbar.doneTitle != doneBarButtonItemText {
                                        textField.addPreviousNextRightOnKeyboardWithTarget(self, rightButtonTitle: toolbarDoneBarButtonItemText!, previousAction: #selector(self.previousAction(_:)), nextAction: #selector(self.nextAction(_:)), rightButtonAction: #selector(self.doneAction(_:)), shouldShowPlaceholder: shouldShowTextFieldPlaceholder)
                                    }
                                } else if (toolbarDoneBarButtonItemText == nil && toolbar.doneTitle != nil) ||
                                    (toolbarDoneBarButtonItemImage == nil && toolbar.doneImage != nil) {
                                    //Now adding textField placeholder text as title of IQToolbar  (Enhancement ID: #27)
                                    textField.addPreviousNextDoneOnKeyboardWithTarget(self, previousAction: #selector(self.previousAction(_:)), nextAction: #selector(self.nextAction(_:)), doneAction: #selector(self.doneAction(_:)), shouldShowPlaceholder: shouldShowTextFieldPlaceholder)
                                }
                            }
                        }

                        textField.inputAccessoryView?.tag = IQKeyboardManager.kIQPreviousNextButtonToolbarTag //  (Bug ID: #78)
                   }
                    
                    if textField.inputAccessoryView is IQToolbar && textField.inputAccessoryView?.tag == IQKeyboardManager.kIQPreviousNextButtonToolbarTag {
                        
                        let toolbar = textField.inputAccessoryView as! IQToolbar
                        
                        //  Setting toolbar to keyboard.
                        if let _textField = textField as? UITextField {
                            
                            //Bar style according to keyboard appearance
                            switch _textField.keyboardAppearance {
                                
                            case UIKeyboardAppearance.Dark:
                                toolbar.barStyle = UIBarStyle.Black
                                toolbar.tintColor = UIColor.whiteColor()
                            default:
                                toolbar.barStyle = UIBarStyle.Default

                                if shouldToolbarUsesTextFieldTintColor {
                                    toolbar.tintColor = _textField.tintColor
                                } else if let tintColor = toolbarTintColor {
                                    toolbar.tintColor = tintColor
                                } else {
                                    toolbar.tintColor = UIColor.blackColor()
                                }
                            }
                        } else if let _textView = textField as? UITextView {
                            
                            //Bar style according to keyboard appearance
                            switch _textView.keyboardAppearance {
                                
                            case UIKeyboardAppearance.Dark:
                                toolbar.barStyle = UIBarStyle.Black
                                toolbar.tintColor = UIColor.whiteColor()
                            default:
                                toolbar.barStyle = UIBarStyle.Default

                                if shouldToolbarUsesTextFieldTintColor {
                                    toolbar.tintColor = _textView.tintColor
                                } else if let tintColor = toolbarTintColor {
                                    toolbar.tintColor = tintColor
                                } else {
                                    toolbar.tintColor = UIColor.blackColor()
                                }
                            }
                        }
                        
                        //Setting toolbar title font.   //  (Enhancement ID: #30)
                        if shouldShowTextFieldPlaceholder == true && textField.shouldHideTitle == false {
                            
                            //Updating placeholder font to toolbar.     //(Bug ID: #148, #272)
                            if toolbar.title == nil || toolbar.title != textField.drawingPlaceholderText {
                                toolbar.title = textField.drawingPlaceholderText
                            }
                            
                            //Setting toolbar title font.   //  (Enhancement ID: #30)
                            if placeholderFont != nil {
                                toolbar.titleFont = placeholderFont
                            }
                        }
                        else {
                            
                            toolbar.title = nil
                        }

                        //In case of UITableView (Special), the next/previous buttons has to be refreshed everytime.    (Bug ID: #56)
                        //	If firstTextField, then previous should not be enabled.
                        if siblings[0] == textField {
                            textField.setEnablePrevious(false, isNextEnabled: true)
                        } else if siblings.last  == textField {   //	If lastTextField then next should not be enaled.
                            textField.setEnablePrevious(true, isNextEnabled: false)
                        } else {
                            textField.setEnablePrevious(true, isNextEnabled: true)
                        }
                    }
                }
            }
        }
    }
    
    /** Remove any toolbar if it is IQToolbar. */
    private func removeToolbarIfRequired() {    //  (Bug ID: #18)
        
        //	Getting all the sibling textFields.
        if let siblings = responderViews() {
            
            for view in siblings {
                
                if let toolbar = view.inputAccessoryView as? IQToolbar {

                    //setInputAccessoryView: check   (Bug ID: #307)
                    if view.respondsToSelector(Selector("setInputAccessoryView:")) && (toolbar.tag == IQKeyboardManager.kIQDoneButtonToolbarTag || toolbar.tag == IQKeyboardManager.kIQPreviousNextButtonToolbarTag) {
                        
                        if let textField = view as? UITextField {
                            textField.inputAccessoryView = nil
                        } else if let textView = view as? UITextView {
                            textView.inputAccessoryView = nil
                        }
                    }
                }
            }
        }
    }
    
    public var enableDebugging = false

    private func showLog(logString: String) {
        
        if enableDebugging {
            print("IQKeyboardManager: " + logString)
        }
    }
}

