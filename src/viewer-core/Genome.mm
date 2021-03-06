//
//  Genome.m
//  viewer-macos
//
//  Created by David M. Bryson on 1/24/12.
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

#import "Genome.h"

#import "NSString+Apto.h"

NSString* const AvidaPasteboardTypeGenome = @"org.devosoft.avida.genome";

@implementation Genome

- (Genome*) initWithGenome:(NSString*)genome name:(NSString*)genomeName {
  genomeStr = genome;
  name = genomeName;
  return self;
}

@synthesize genomeStr;
@synthesize name;

+ (Genome*) genomeFromPasteboard:(NSPasteboard*)pboard {
  NSArray* classes = [[NSArray alloc] initWithObjects:[Genome class], nil];
  NSDictionary* options = [NSDictionary dictionary];
  NSArray* copiedItems = [pboard readObjectsForClasses:classes options:options];
  if (copiedItems != nil && [copiedItems count] > 0) {
    return (Genome*)[copiedItems objectAtIndex:0];
  }
  
  return nil;
}

+ (void) writeGenome:(Genome*)genome toPasteboard:(NSPasteboard*)pboard {
  [pboard writeObjects:[NSArray arrayWithObject:genome]];
}





- (void) encodeWithCoder:(NSCoder*)encoder {
  [encoder encodeObject:genomeStr];
  [encoder encodeObject:name];
}

- (id) initWithCoder:(NSCoder*)decoder {
  genomeStr = [[decoder decodeObject] retain];
  name = [[decoder decodeObject] retain];
  return self;
}


- (NSArray*) writableTypesForPasteboard:(NSPasteboard*)pboard {
  static NSArray* writableTypes = nil;
  if (!writableTypes) {
    writableTypes = [[NSArray alloc] initWithObjects:AvidaPasteboardTypeGenome, nil];
  }
  return writableTypes;
}

- (id) pasteboardPropertyListForType:(NSString*)type {
  if ([type isEqualToString:AvidaPasteboardTypeGenome]) {
    return [NSKeyedArchiver archivedDataWithRootObject:self];
  }
  return nil;
}


+ (NSArray*) readableTypesForPasteboard:(NSPasteboard*)pboard {
  static NSArray* readableTypes = nil;
  if (!readableTypes) {
    readableTypes = [[NSArray alloc] initWithObjects:AvidaPasteboardTypeGenome, nil];
  }
  return readableTypes;
}

+ (NSPasteboardReadingOptions)readingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pboard {
  if ([type isEqualToString:AvidaPasteboardTypeGenome]) {
    return NSPasteboardReadingAsKeyedArchive;
  }
  return 0;
}


@end
