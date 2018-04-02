//
//  ViewController.swift
//  Nodejs Scratchpad
//
//  Created by Aravind on 06/12/17.
//  Copyright © 2017 ARAVIND VS. All rights reserved.
//

import Cocoa
import Foundation
import JavaScriptCore
import Highlightr

class ViewController: NSViewController {
    @IBOutlet weak var runCodeButton: NSButton!
    @IBOutlet var outputView: NSTextView!
    var codeIsRunning: Bool = false
    var currentTask: Process!
    let outpipe = Pipe()
    var dataObserver : NSObjectProtocol? = nil
    var errorObserver : NSObjectProtocol? = nil
    @IBOutlet weak var statusText: NSTextField!

    @IBOutlet weak var codeView : NSTextView!
    @IBOutlet weak var clipView: NSClipView!
    let textStorage = CodeAttributedString()
    
    override func viewDidLoad() {
        super.viewDidLoad();
        // Highlightr
        textStorage.language = "javascript"
        textStorage.highlightr.setTheme(to: "github")
        textStorage.highlightr.theme.codeFont = NSFont(name: "Courier", size: 14)
        textStorage.addLayoutManager(codeView.layoutManager!)
        codeView.backgroundColor = (textStorage.highlightr.theme.themeBackgroundColor)!
        codeView.insertionPointColor = NSColor.black
        codeView.isAutomaticQuoteSubstitutionEnabled = false
        codeView.enabledTextCheckingTypes = 0
        codeView.lnv_setUpLineNumberView();
    }
    
    func runInJsCore(cmd: String) -> (output: String?, error: String){
        let context = JSContext()!
        context.evaluateScript("var console = { log: function(message) { _consoleLog(message) } }")
        let consoleLog: @convention(block) (String) -> Void = { message in
            print("console.log: " + message)
        }
        context.setObject(unsafeBitCast(consoleLog, to: AnyObject.self), forKeyedSubscript: "_consoleLog" as (NSCopying & NSObjectProtocol)!)
        let tripleNum = context.evaluateScript(cmd)
        return(tripleNum!.toString(),"No error");
    }
    
    func captureStandardOutputAndRouteToTextView(_ task:Process) {
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        let errpipe = Pipe()
        task.standardError = errpipe
        outputPipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
        errpipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
        if (dataObserver != nil) {
            NotificationCenter.default.removeObserver(dataObserver)
        }
        dataObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable, object: outputPipe.fileHandleForReading , queue: nil) {
            notification in
            let output = outputPipe.fileHandleForReading.availableData
            let outputString = String(data: output, encoding: String.Encoding.utf8) ?? ""
            DispatchQueue.main.async(execute: {
                let previousOutput = self.outputView.string ?? ""
                let nextOutput = previousOutput + "\n" + outputString
                self.outputView.string = nextOutput
                
                let range = NSRange(location:nextOutput.characters.count,length:0)
                self.outputView.scrollRangeToVisible(range)
                
            })
            outputPipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
        }
        
        if (errorObserver != nil) {
            NotificationCenter.default.removeObserver(errorObserver)
        }
        errorObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable, object: errpipe.fileHandleForReading , queue: nil) {
            notification in
            let error = errpipe.fileHandleForReading.availableData
            let errorString = String(data: error, encoding: String.Encoding.utf8) ?? ""
            DispatchQueue.main.async(execute: {
                self.outputView.string = errorString
                let range = NSRange(location:errorString.characters.count,length:0)
                self.outputView.scrollRangeToVisible(range)
            })
            errpipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
        }
        
    }
    
    func updateStatus (buttonText: String, statusText: String){
        DispatchQueue.main.async( execute: {
            self.runCodeButton.title = buttonText
            self.statusText.stringValue = statusText
        })
    }
    
    func runCommand(view: NSTextView,cmd : String, args : String...) -> Void {
        if(self.codeIsRunning){
            self.currentTask.terminate();
            updateStatus(buttonText: "Run",statusText: "Idle");
            self.codeIsRunning = false
            return
        }
        
        var task = Process()
        self.currentTask = task;
        task.launchPath = cmd
        task.arguments = args

        captureStandardOutputAndRouteToTextView(task)
        self.codeIsRunning = true;
        task.launch()
        task.waitUntilExit()
        self.codeIsRunning = false;
        let status = task.terminationStatus
        updateStatus(buttonText: "Run",statusText: "Idle");
        return
    }
    
    @IBAction func closeButtonAction(_ sender: NSButton) {
        NSApp.terminate(self)
    }
    
    @IBAction func runCode(_ sender: NSButton){
        self.outputView.string = "";
        updateStatus(buttonText: "Stop",statusText: "Evaluating...")
        var code: String = "";
        code =  codeView.textStorage?.string ?? "";
        
        print(code)
        
        let weakSelf = self
        DispatchQueue.global().async {
          weakSelf.runCommand(view:weakSelf.outputView,cmd: "/usr/local/bin/node", args: "-e",code);
        }
    
    }
    
}

