//
//  EventMonitor.swift
//  Nodejs Scratchpad
//
//  Created by Aravind on 06/12/17.
//  Copyright © 2017 ARAVIND VS. All rights reserved.
//

import Cocoa

open class EventMonitor {
	
	fileprivate var monitor: AnyObject?
	fileprivate let mask: NSEvent.EventTypeMask
	fileprivate let handler: (NSEvent?) -> ()
	
	public init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> ()) {
		self.mask = mask
		self.handler = handler
	}
	
	deinit {
		stop()
	}
	
	open func start() {
		monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) as AnyObject?
	}
	
	open func stop() {
		if monitor != nil {
			NSEvent.removeMonitor(monitor!)
			monitor = nil
		}
	}
}
