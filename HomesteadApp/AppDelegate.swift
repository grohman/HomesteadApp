//
//  AppDelegate.swift
//  HomesteadApp
//
//  Created by Grohman on 30.01.15.
//  Copyright (c) 2015 Grohman. All rights reserved.
//

import Cocoa
import AppKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var StartAction: NSMenuItem!
    @IBOutlet weak var SshAction: NSMenuItem!
    @IBOutlet weak var OpenAtLoginAction: NSMenuItem!


    let statusbarItem = NSStatusBar.systemStatusBar().statusItemWithLength(-1)
    
    @IBAction func StartActionClicked(sender: NSMenuItem) {
        let task = NSTask()
        task.launchPath = "~/.composer/vendor/bin/homestead"
        
        if(sender.state == NSOnState) {
            sender.state = NSOffState
            task.arguments = ["suspend"]
        } else {
            sender.state = NSOnState
            task.arguments = ["up"]
        }
        
        task.launch()
        task.waitUntilExit()
        setStartActionState(StartAction)
    }

    @IBAction func OpenAtLoginActionClicked(sender: NSMenuItem) {
        let itemReferences = itemReferencesInLoginItems()
        let shouldBeToggled = (itemReferences.existingReference == nil)
        let loginItemsRef = LSSharedFileListCreate(
            nil,
            kLSSharedFileListSessionLoginItems.takeRetainedValue(),
            nil
            ).takeRetainedValue() as LSSharedFileListRef?
        if loginItemsRef != nil {
            if shouldBeToggled {
                if let appUrl : CFURLRef = NSURL.fileURLWithPath(NSBundle.mainBundle().bundlePath) {
                    LSSharedFileListInsertItemURL(
                        loginItemsRef,
                        itemReferences.lastReference,
                        nil,
                        nil,
                        appUrl,
                        nil,
                        nil
                    )
                    sender.state = NSOnState
                    println("Application was added to login items")
                }
            } else {
                if let itemRef = itemReferences.existingReference {
                    LSSharedFileListItemRemove(loginItemsRef,itemRef);
                    sender.state = NSOffState
                    println("Application was removed from login items")
                }
            }
        }
    }
    
    @IBAction func ExitActionClicked(sender: NSMenuItem) {
        NSApplication.sharedApplication().terminate(self)
    }
    
    @IBAction func SshActionClicked(sender: NSMenuItem) {
        let makeScript = NSTask()
        
        makeScript.launchPath = "/bin/sh"
        makeScript.arguments = ["-c", "echo ~/.composer/vendor/bin/homestead ssh > /tmp/homesteadssh.script"]
        makeScript.launch()
        
        let chmod = NSTask()
        chmod.launchPath = "/bin/chmod"
        chmod.arguments = ["+x", "/tmp/homesteadssh.script"]
        chmod.launch()
        
        
        let runScript = NSTask()
        runScript.launchPath = "/usr/bin/open"
        runScript.arguments = ["-a", "Terminal.app", "/tmp/homesteadssh.script"]
        runScript.launch()
    }
    
    func setStartActionState(StartAction: NSMenuItem) {
        if(getHomesteadPid() == false) {
            StartAction.state = NSOffState
            StartAction.title = "Homestead up"
            SshAction.enabled = false
        } else {
            StartAction.state = NSOnState
            StartAction.title = "Click to suspend Homestead"
            SshAction.enabled = true
        }
    }
    
    func getHomesteadPid() -> Bool {
        let homesteadRunningTask = NSTask()

        homesteadRunningTask.launchPath = "/bin/sh"
        homesteadRunningTask.arguments = ["-c", "/usr/bin/vagrant global-status | grep -i homestead| grep -i running | awk {'print $1'}"]
        
        let pipe = NSPipe()
        homesteadRunningTask.standardOutput = pipe
        homesteadRunningTask.launch()
        homesteadRunningTask.waitUntilExit()
        
        let homesteadRunningData = pipe.fileHandleForReading.readDataToEndOfFile()
        let homesteadRunning: String = NSString(data: homesteadRunningData, encoding: NSUTF8StringEncoding)! as String
        print("homestead pid:" + homesteadRunning)
        
        if(homesteadRunning == "") {
            return false;
        }
        return true
    }
    
    func setOpenAtLoginActionState(OpenAtLoginAction: NSMenuItem) {
        let itemReferences = itemReferencesInLoginItems()
        if let itemRef = itemReferences.existingReference {
            OpenAtLoginAction.state = NSOnState
        } else {
            OpenAtLoginAction.state = NSOffState
        }
    }
    
    func applicationIsInStartUpItems() -> Bool {
        return (itemReferencesInLoginItems().existingReference != nil)
    }
    
    func itemReferencesInLoginItems() -> (existingReference: LSSharedFileListItemRef?, lastReference: LSSharedFileListItemRef?) {
        var itemUrl : UnsafeMutablePointer<Unmanaged<CFURL>?> = UnsafeMutablePointer<Unmanaged<CFURL>?>.alloc(1)
        if let appUrl : NSURL = NSURL.fileURLWithPath(NSBundle.mainBundle().bundlePath) {
            let loginItemsRef = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil).takeRetainedValue() as LSSharedFileListRef?
            if loginItemsRef != nil {
                let loginItems: NSArray = LSSharedFileListCopySnapshot(loginItemsRef, nil).takeRetainedValue() as NSArray
                println("There are \(loginItems.count) login items")
                if(loginItems.count > 0)
                {
                    let lastItemRef: LSSharedFileListItemRef = loginItems.lastObject as! LSSharedFileListItemRef
                    for var i = 0; i < loginItems.count; ++i {
                        let currentItemRef: LSSharedFileListItemRef = loginItems.objectAtIndex(i) as! LSSharedFileListItemRef
                        if LSSharedFileListItemResolve(currentItemRef, 0, itemUrl, nil) == noErr {
                            if let urlRef: NSURL =  itemUrl.memory?.takeRetainedValue() {
                                println("URL Ref: \(urlRef.lastPathComponent)")
                                if urlRef.isEqual(appUrl) {
                                    return (currentItemRef, lastItemRef)
                                }
                            }
                        }
                        else {
                            println("Unknown login application")
                        }
                    }
                    //The application was not found in the startup list
                    return (nil, lastItemRef)
                }
                else
                {
                    let addatstart: LSSharedFileListItemRef = kLSSharedFileListItemBeforeFirst.takeRetainedValue()
                    
                    return(nil,addatstart)
                }
            }
        }
        return (nil, nil)
    }
    
    func applicationDidFinishLaunching(aNotification: NSNotification){
        let icon = NSImage(named: "statusbarIcon");
        icon?.setTemplate(true)
        statusMenu.autoenablesItems = false
        
        statusbarItem.image = icon
        statusbarItem.menu = statusMenu
        
        setStartActionState(StartAction)
        setOpenAtLoginActionState(OpenAtLoginAction)
    }
    
}