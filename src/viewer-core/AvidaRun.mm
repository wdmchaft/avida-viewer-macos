//
//  AvidaRun.mm
//  avida/apps/viewer-macos
//
//  Created by David M. Bryson on 10/27/10.
//  Copyright 2010-2012 Michigan State University. All rights reserved.
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

#import "AvidaRun.h"

#include "avida/viewer/Driver.h"

#import "ViewerListener.h"

#include <Foundation/Foundation.h>
#include <objc/objc-auto.h>

class AutoreleasePoolContainer
{
private:
  NSAutoreleasePool* m_pool;
  
public:
  AutoreleasePoolContainer() : m_pool([[NSAutoreleasePool alloc] init]) { ; }
  ~AutoreleasePoolContainer()
  {
    [m_pool release];
  }
};

static Apto::ThreadSpecific<AutoreleasePoolContainer> s_autorelease_pool;

void handleDriverCallback(Avida::DriverEvent event)
{
  if (event == Avida::THREAD_START) {
    if (objc_collectingEnabled()) {
      objc_registerThreadWithCollector();
    } else {
      AutoreleasePoolContainer* pool = s_autorelease_pool.Get();
      if (pool == NULL) {
        pool = new AutoreleasePoolContainer;
        s_autorelease_pool.Set(pool);
      }
    }
  } else if (event == Avida::THREAD_END) {
    s_autorelease_pool.Set(NULL);
  }
}

@implementation AvidaRun

- (id) init {
  return nil;
}

- (AvidaRun*) initWithDirectory:(NSString*)dir {
  return [self initWithDirectory:dir shouldPauseAt:-1];
}

- (AvidaRun*) initWithDirectory:(NSString*)dir shouldPauseAt:(Avida::Update)update {
  self = [super init];
  
  if (self) { 
    Apto::String config_path([dir cStringUsingEncoding:NSASCIIStringEncoding]);
    driver = Avida::Viewer::Driver::InitWithDirectory(config_path);
    if (!driver) return nil;
    driver->RegisterCallback(&handleDriverCallback);
    
    if (update == -1) driver->Pause();
    else driver->PauseAt(update);
    
    driver->Start();
  }
  
  return self;
}

- (Avida::World*) world
{
  return driver->GetWorld();
}

- (cWorld*) oldworld
{
  return driver->GetOldWorld();
}


- (void) dealloc {
  delete driver;
  driver = NULL;
  [super dealloc];
}


- (void) finalize { 
  delete driver;
  driver = NULL;
  [super finalize];
}


- (int) numOrganisms {
  return driver->NumOrganisms();
}

- (int) currentUpdate {
  return driver->CurrentUpdate();
}


- (NSSize) worldSize {
  NSSize size;
  size.width = driver->WorldX();
  size.height = driver->WorldY();
  return size;
}

- (void) setWorldSize:(NSSize)size {
  driver->SetWorldSize(size.width, size.height);
}


- (double) mutationRate {
  return driver->MutationRate();
}

- (void) setMutationRate:(double)rate {
  driver->SetMutationRate(rate);
}


- (int) placementMode {
  return driver->PlacementMode();
}

- (void) setPlacementMode:(int)mode {
  driver->SetPlacementMode(mode);
}


- (int) randomSeed {
  return driver->RandomSeed();
}

- (void) setRandomSeed:(int)seed {
  driver->SetRandomSeed(seed);
}



- (double) reactionValueOf:(const Apto::String&)reaction_name {
  return driver->ReactionValue(reaction_name);
}

- (void) setReactionValueOf:(const Apto::String&)reaction_name to:(double)value {
  driver->SetReactionValue(reaction_name, value);
}



- (bool) hasStarted {
  return driver->HasStarted();
}

- (bool) willPause {
  return (driver->GetPauseState() == Avida::Viewer::DRIVER_PAUSED);
}

- (bool) isPaused {
  return driver->IsPaused();
}

- (bool) hasFinished {
  return driver->HasFinished();
}


- (void) pause {
  driver->Pause();
}

- (void) pauseAt:(Avida::Update)update {
  driver->PauseAt(update);
}


- (void) resume {
  driver->Resume();
}


- (void) end {
  driver->Finish();
}

- (void) injectGenome:(Avida::GenomePtr)genome atX:(int)x Y:(int)y {
  driver->InjectGenomeAt(genome, x, y);
}

- (bool) hasPendingInjects {
  return driver->HasPendingInjects();
}


- (void) attachListener:(id<ViewerListener>)listener {
  if (driver) driver->AttachListener([listener listener]);
}


- (void) detachListener:(id<ViewerListener>)listener {
  if (driver) driver->DetachListener([listener listener]);
}

- (void) attachRecorder:(Avida::Data::RecorderPtr)recorder {
  if (driver) driver->AttachRecorder(recorder);
}

- (void) attachRecorder:(Avida::Data::RecorderPtr)recorder concurrentUpdate:(BOOL)concurrentUpdate {
  if (driver) driver->AttachRecorder(recorder, (concurrentUpdate) ? true : false);
}

- (void) detachRecorder:(Avida::Data::RecorderPtr)recorder {
  if (driver) driver->DetachRecorder(recorder);
}

@end
