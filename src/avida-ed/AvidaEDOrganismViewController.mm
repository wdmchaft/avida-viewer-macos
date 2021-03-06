//
//  AvidaEDOrganismViewController.mm
//  viewer-macos
//
//  Created by David Michael Bryson on 3/5/12.
//  Copyright 2012 Michigan State University. All rights reserved.
//  http://avida.devosoft.org/viewer-macos
//
//  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
//  following conditions are met:
//  
//  1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the
//      following disclaimer.
//  2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the
//      following disclaimer in the documentation and/or other materials provided with the distribution.
//  3.  Neither the name of Michigan State University, nor the names of contributors may be used to endorse or promote
//      products derived from this software without specific prior written permission.
//  
//  THIS SOFTWARE IS PROVIDED BY MICHIGAN STATE UNIVERSITY AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
//  INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL MICHIGAN STATE UNIVERSITY OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
//  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
//  USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//  Authors: David M. Bryson <david@programerror.com>
//

#import "AvidaEDOrganismViewController.h"

#import "AvidaEDController.h"
#import "AvidaEDEnvActionsDataSource.h"
#import "AvidaEDOrganismSettingsViewController.h"
#import "OrgExecStateValue.h"
#import "AvidaRun.h"
#import "Freezer.h"
#import "NSFileManager+TemporaryDirectory.h"
#import "NSString+Apto.h"
#import "OrganismView.h"

#include "avida/environment/ActionTrigger.h"
#include "avida/environment/Manager.h"
#include "avida/environment/Product.h"
#include "avida/viewer/Freezer.h"


@interface AvidaEDOrganismViewController ()
- (void) viewDidLoad;
@end


@interface AvidaEDOrganismViewController (hidden)
- (void) setSnapshot:(int)snapshot;
- (void) setTaskCountsWithSnapshot:(const Avida::Viewer::HardwareSnapshot&)snapshot;
- (void) setStateDisplayWithSnapshot:(const Avida::Viewer::HardwareSnapshot&)snapshot;

- (void) startAnimation;
- (void) stopAnimation;
- (void) nextAnimationFrame:(id)sender;

- (void) createSettingsPopover;
@end


@implementation AvidaEDOrganismViewController (hidden)

- (void) setSnapshot:(int)snapshot {
  assert(trace);

  if (snapshot >= 0 && snapshot < trace->SnapshotCount()) {
    curSnapshotIndex = snapshot;
    [self setTaskCountsWithSnapshot:trace->Snapshot(snapshot)];
    [self setStateDisplayWithSnapshot:trace->Snapshot(snapshot)];
    [orgView setSnapshot:&trace->Snapshot(snapshot)];
  }
  
  [sldStatus setIntValue:curSnapshotIndex];
  
  if (curSnapshotIndex == 0) {
    [btnBegin setEnabled:NO];
    [btnBack setEnabled:NO];
    [btnGo setEnabled:YES];
    [btnForward setEnabled:YES];
    [btnEnd setEnabled:YES];
  } else if (curSnapshotIndex == (trace->SnapshotCount() - 1)) {
    [self stopAnimation];
    [btnBegin setEnabled:YES];
    [btnBack setEnabled:YES];
    [btnGo setEnabled:NO];
    [btnForward setEnabled:NO];
    [btnEnd setEnabled:NO];
  } else {
    [btnBegin setEnabled:YES];
    [btnBack setEnabled:YES];
    [btnGo setEnabled:YES];
    [btnForward setEnabled:YES];
    [btnEnd setEnabled:YES];
  }
}



- (void) setTaskCountsWithSnapshot:(const Avida::Viewer::HardwareSnapshot&)snapshot {
  
  for (NSUInteger i = 0; i < [envActions entryCount]; i++) {
    NSString* entry_name = [envActions entryAtIndex:i];
    [envActions updateEntry:entry_name withValue:[NSNumber numberWithInt:snapshot.FunctionCount([entry_name UTF8String])]];
  }
  [tblTaskCounts reloadData];
}


- (void) setStateDisplayWithSnapshot:(const Avida::Viewer::HardwareSnapshot&)snapshot {
  
  // Handle registers
  if ([arrRegisters count] != snapshot.NumRegisters()) {
    NSRange range = NSMakeRange(0, [[arrctlrRegisters arrangedObjects] count]);
    [arrctlrRegisters removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:range]];
    for (int i = 0; i < snapshot.NumRegisters(); i++) {
      NSString* prefix = [NSString stringWithFormat:@"%cX: ", (char)('A' + i)];
      OrgExecStateValue* sv = [[OrgExecStateValue alloc] initWithPrefix:prefix];
      [sv setValue:snapshot.Register(i)];
      [arrctlrRegisters addObject:sv];
    }
  } else {
    for (int i = 0; i < snapshot.NumRegisters(); i++)
      [(OrgExecStateValue*)[arrRegisters objectAtIndex:i] setValue:snapshot.Register(i)];
  }
  
  // Handle input buffer
  const Apto::Array<int>& input_buf = snapshot.Buffer("input");
  if ([arrInputBuffer count] != input_buf.GetSize()) {
    NSRange range = NSMakeRange(0, [[arrctlrInputBuffer arrangedObjects] count]);
    [arrctlrInputBuffer removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:range]];
    for (int i = 0; i < input_buf.GetSize(); i++) {
      OrgExecStateValue* sv = [[OrgExecStateValue alloc] initWithPrefix:@""];
      [sv setValue:input_buf[i]];
      [arrctlrInputBuffer addObject:sv];
    }
  } else {
    for (int i = 0; i < input_buf.GetSize(); i++)
      [(OrgExecStateValue*)[arrInputBuffer objectAtIndex:i] setValue:input_buf[i]];
  }
  
  // handle output buffer
  const Apto::Array<int>& output_buf = snapshot.Buffer("output");
  if ([arrOutputBuffer count] != output_buf.GetSize()) {
    NSRange range = NSMakeRange(0, [[arrctlrOutputBuffer arrangedObjects] count]);
    [arrctlrOutputBuffer removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:range]];
    for (int i = 0; i < output_buf.GetSize(); i++) {
      OrgExecStateValue* sv = [[OrgExecStateValue alloc] initWithPrefix:@""];
      [sv setValue:output_buf[i]];
      [arrctlrOutputBuffer addObject:sv];
    }
  } else {
    for (int i = 0; i < output_buf.GetSize(); i++)
      [(OrgExecStateValue*)[arrOutputBuffer objectAtIndex:i] setValue:output_buf[i]];
  }
  
  // handle current stack
  const Apto::Array<int>& cur_stack = snapshot.Buffer(snapshot.SelectedBuffer());
  if ([arrCurStack count] != cur_stack.GetSize()) {
    NSRange range = NSMakeRange(0, [[arrctlrCurStack arrangedObjects] count]);
    [arrctlrCurStack removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:range]];
    for (int i = 0; i < cur_stack.GetSize(); i++) {
      OrgExecStateValue* sv = [[OrgExecStateValue alloc] initWithPrefix:@""];
      [sv setValue:cur_stack[i]];
      [arrctlrCurStack addObject:sv];
    }
  } else {
    for (int i = 0; i < cur_stack.GetSize(); i++)
      [(OrgExecStateValue*)[arrCurStack objectAtIndex:i] setValue:cur_stack[i]];
  }
  
}


- (void) startAnimation {
  if (tmrAnim == nil) {
    tmrAnim = [NSTimer scheduledTimerWithTimeInterval:0.075 target:self selector:@selector(nextAnimationFrame:) userInfo:self repeats:YES];
    [btnGo setTitle:@"Stop"];
  }
}

- (void) stopAnimation {
  if (tmrAnim != nil) {
    [tmrAnim invalidate];
    tmrAnim = nil;
    [btnGo setTitle:@"Run"];
  }
}

- (void) nextAnimationFrame:(id)sender {
  [self setSnapshot:(curSnapshotIndex + 1)];
}


- (void) createSettingsPopover {
  if (popoverSettings == nil) {
    // create and setup our popover
    popoverSettings = [[NSPopover alloc] init];
    
    // the popover retains us and we retain the popover, we drop the popover whenever it is closed to avoid a cycle
    popoverSettings.contentViewController = ctlrSettings;    
    popoverSettings.appearance = NSPopoverAppearanceHUD;  
    popoverSettings.animates = YES;
    
    // AppKit will close the popover when the user interacts with a user interface element outside the popover.
    // note that interacting with menus or panels that become key only when needed will not cause a transient popover to close.
    popoverSettings.behavior = NSPopoverBehaviorTransient;
    
    // so we can be notified when the popover appears or closes
    popoverSettings.delegate = self;
  }
}

@end


@implementation AvidaEDOrganismViewController

@synthesize arrRegisters;
@synthesize arrInputBuffer;
@synthesize arrOutputBuffer;
@synthesize arrCurStack;


- (id) initWithWorld:(AvidaRun*)world {
  self = [super initWithNibName:@"AvidaED-OrganismView" bundle:nil];
  if (self) {
    tmrAnim = nil;
    testWorld = world;
  }
  return self;
}

- (void) loadView {
  [super loadView];
  [self viewDidLoad];
}


- (void) viewDidLoad {
  
  orgView.dropDelegate = dropDelegate;
  
  [btnBegin setEnabled:NO];
  [btnBack setEnabled:NO];
  [btnGo setEnabled:NO];
  [btnGo setTitle:@"Run"];
  [btnForward setEnabled:NO];
  [btnEnd setEnabled:NO];
  
  [sldStatus setEnabled:NO];
  [txtOrgName setStringValue:@"(none)"];
  [txtOrgName setEnabled:NO];
  
  [orgView registerForDraggedTypes:[NSArray arrayWithObjects:AvidaPasteboardTypeFreezerID, nil]];
  
  envActions = [[AvidaEDEnvActionsDataSource alloc] init];
  
  Avida::Environment::ManagerPtr env = Avida::Environment::Manager::Of([testWorld world]);
  Avida::Environment::ConstActionTriggerIDSetPtr trigger_ids = env->GetActionTriggerIDs();
  for (Avida::Environment::ConstActionTriggerIDSetIterator it = trigger_ids->Begin(); it.Next();) {
    Avida::Environment::ConstActionTriggerPtr action = env->GetActionTrigger(*it.Get());
    NSString* entryName = [NSString stringWithAptoString:action->GetID()];
    NSString* entryDesc = [NSString stringWithAptoString:action->GetDescription()];
    [envActions addNewEntry:entryName withDescription:entryDesc withOrder:action->TempOrdering()];
  }
  
  [tblTaskCounts setDataSource:envActions];
  [tblTaskCounts reloadData];
}


- (void) setDropDelegate:(id<DropDelegate>)delegate {
  dropDelegate = delegate;
  if (orgView) [orgView setDropDelegate:delegate];
}




- (IBAction) selectSnapshot:(id)sender {
  [self stopAnimation];
  int snapshot = [sldStatus intValue];
  [self setSnapshot:snapshot];
}


- (IBAction) nextSnapshot:(id)sender {
  [self stopAnimation];
  int snapshot = [sldStatus intValue] + 1;
  if (snapshot >= trace->SnapshotCount()) snapshot = trace->SnapshotCount() - 1;
  [self setSnapshot:snapshot];
}

- (IBAction) prevSnapshot:(id)sender {
  [self stopAnimation];
  int snapshot = [sldStatus intValue] - 1;
  if (snapshot < 0) snapshot = 0;
  [self setSnapshot:snapshot];
}

- (IBAction) firstSnapshot:(id)sender {
  [self stopAnimation];
  [self setSnapshot:0];
}

- (IBAction) lastSnapshot:(id)sender {
  [self stopAnimation];
  [self setSnapshot:(trace->SnapshotCount() - 1)];
}


- (IBAction) toggleAnimation:(id)sender {
  if (tmrAnim == nil) {
    [self startAnimation];
  } else {
    [self stopAnimation];
  }
}

- (IBAction) showSettings:(id)sender {
  NSButton* targetButton = (NSButton*)sender;
  
  [self createSettingsPopover];
  
  [popoverSettings showRelativeToRect:[targetButton bounds] ofView:sender preferredEdge:NSMinYEdge];
}


- (void) setGenome:(Avida::GenomePtr)genome withName:(NSString*)name {
  // Trace genome
  trace = Avida::Viewer::OrganismTracePtr(new Avida::Viewer::OrganismTrace([testWorld oldworld], genome));
  
  [txtOrgName setStringValue:name];
  [txtOrgName setEnabled:YES];
  
  if (trace->SnapshotCount() > 0) {
    [sldStatus setMinValue:0];
    [sldStatus setMaxValue:trace->SnapshotCount() - 1];
    [sldStatus setIntValue:0];
    [sldStatus setEnabled:YES];
    
    [btnGo setEnabled:YES];
    [btnGo setTitle:@"Run"];
    
    [self setSnapshot:0];
  } else {
    [sldStatus setIntValue:0];
    [sldStatus setEnabled:NO];
    
    [btnBegin setEnabled:NO];
    [btnBack setEnabled:NO];
    [btnGo setEnabled:NO];
    [btnGo setTitle:@"Run"];
    [btnForward setEnabled:NO];
    [btnEnd setEnabled:NO];
    
    [orgView setSnapshot:NULL];
  }
}








- (void)popoverWillShow:(NSNotification *)notification
{
//  NSPopover* popover = [notification object];
  // add new code here when the popover will be shown
}


- (void)popoverDidShow:(NSNotification *)notification
{
  // add new code here after the popover has been shown
}


- (void)popoverWillClose:(NSNotification *)notification
{
  NSString *closeReason = [[notification userInfo] valueForKey:NSPopoverCloseReasonKey];
  if (closeReason)
  {
    // closeReason can be:
    //      NSPopoverCloseReasonStandard
    //      NSPopoverCloseReasonDetachToWindow
    //
    // add new code here if you want to respond "before" the popover closes
    //
  }
}

- (void)popoverDidClose:(NSNotification *)notification
{
  NSString *closeReason = [[notification userInfo] valueForKey:NSPopoverCloseReasonKey];
  if (closeReason)
  {
    // closeReason can be:
    //      NSPopoverCloseReasonStandard
    //      NSPopoverCloseReasonDetachToWindow
    //
    // add new code here if you want to respond "after" the popover closes
    //
  }
  
  [popoverSettings release];
  popoverSettings = nil;
}

@end
