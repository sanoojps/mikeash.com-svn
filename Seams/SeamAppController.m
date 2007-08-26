//
//  SeamAppController.m
//  Seams
//
//  Created by Michael Ash on 8/25/07.
//  Copyright 2007 Rogue Amoeba Software, LLC. All rights reserved.
//

#import "SeamAppController.h"

#import <QuartzCore/QuartzCore.h>

#import "SeamImageView.h"


@implementation SeamAppController

struct Pixel { uint8_t r, g, b, a; };

- (NSBitmapImageRep *)_repForImage: (NSImage *)image
{
	NSBitmapImageRep *outRep = [[NSBitmapImageRep alloc]
		initWithBitmapDataPlanes: NULL
					  pixelsWide: [image size].width
					  pixelsHigh: [image size].height
				   bitsPerSample: 8
				 samplesPerPixel: 4
						hasAlpha: YES
						isPlanar: NO
				  colorSpaceName: NSCalibratedRGBColorSpace
					 bytesPerRow: 0
					bitsPerPixel: 32];
	NSGraphicsContext *ctx = [NSGraphicsContext graphicsContextWithBitmapImageRep: outRep];
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext: ctx];
	
	[image drawAtPoint: NSZeroPoint fromRect: NSZeroRect operation: NSCompositeCopy fraction: 1.0];
	
	[NSGraphicsContext restoreGraphicsState];
	
	// don't allow pure blalck
	int width = [outRep pixelsWide];
	int height = [outRep pixelsHigh];
	int rowbytes = [outRep bytesPerRow];
	void *ptr = [outRep bitmapData];
	
	int x, y;
	for( y = 0; y < height; y++ )
		for( x = 0; x < width; x++ )
		{
			struct Pixel *p = ptr + x * sizeof( struct Pixel ) + y * rowbytes;
			if( !p->r && !p->g && !p->b )
			{
				p->r = 1;
				p->g = 1;
				p->b = 1;
			}
		}
	
	return [outRep autorelease];
}

- (NSBitmapImageRep *)_repByApplyingCIFilter: (NSString *)filterName arguments: (NSDictionary *)args toRep: (NSBitmapImageRep *)rep
{
	CIImage *before = [[CIImage alloc] initWithBitmapImageRep: rep];
	CIFilter *filter = [CIFilter filterWithName: filterName];
	[filter setDefaults];
	if( args )
		[filter setValuesForKeysWithDictionary: args];
	[filter setValue: before forKey: @"inputImage"];
	
	CIImage *after = [filter valueForKey: @"outputImage"];
	
	NSRect r = { NSZeroPoint, { [rep pixelsWide], [rep pixelsHigh] } };
	NSBitmapImageRep *outRep = [[NSBitmapImageRep alloc]
		initWithBitmapDataPlanes: NULL
					  pixelsWide: NSWidth( r )
					  pixelsHigh: NSHeight( r )
				   bitsPerSample: 8
				 samplesPerPixel: 4
						hasAlpha: YES
						isPlanar: NO
				  colorSpaceName: NSCalibratedRGBColorSpace
					 bytesPerRow: 0
					bitsPerPixel: 32];
	NSGraphicsContext *ctx = [NSGraphicsContext graphicsContextWithBitmapImageRep: outRep];
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext: ctx];
	
	[after drawAtPoint: NSZeroPoint fromRect: r operation: NSCompositeCopy fraction: 1.0];
	
	[NSGraphicsContext restoreGraphicsState];
	
	[before release];
	
	return [outRep autorelease];
}

- (NSBitmapImageRep *)_repBySlicingValues: (int *)values fromRep: (NSBitmapImageRep *)rep
{
	NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc]
		initWithBitmapDataPlanes: NULL
					  pixelsWide: [rep pixelsWide] - 1
					  pixelsHigh: [rep pixelsHigh]
				   bitsPerSample: [rep bitsPerSample]
				 samplesPerPixel: [rep samplesPerPixel]
						hasAlpha: [rep hasAlpha]
						isPlanar: NO
				  colorSpaceName: [rep colorSpaceName]
					 bytesPerRow: 0
					bitsPerPixel: [rep bitsPerPixel]];
	int bytesPerPixel = ([rep bitsPerPixel] + 7) / 8;
	
	void *repPtr = [rep bitmapData];
	int repRowbytes = [rep bytesPerRow];
	
	void *newPtr = [newRep bitmapData];
	int newRowbytes = [newRep bytesPerRow];
	
	int width = [newRep pixelsWide];
	int height = [newRep pixelsHigh];
	
	int y;
	for( y = 0; y < height; y++ )
	{
		// get the location of the cut
		int cutBytes = values[y] * bytesPerPixel;
		
//		memcpy( newPtr, repPtr, MIN( newRowbytes, repRowbytes ) );
//		struct Pixel *p = newPtr + cutBytes;
//		p->r = 255;
//		p->g = 0;
//		p->b = 0;
		
		// copy the first part of the line verbatim
		memcpy( newPtr, repPtr, cutBytes );
		
		// copy the second part of the line, offset
		memcpy( newPtr + cutBytes, repPtr + cutBytes + bytesPerPixel, width * bytesPerPixel - cutBytes );
		
		repPtr += repRowbytes;
		newPtr += newRowbytes;
	}
	
	return [newRep autorelease];
}

- (NSBitmapImageRep *)_shrinkRep: (NSBitmapImageRep *)rep
{
	NSBitmapImageRep *costRep = [self _repByApplyingCIFilter: @"CIEdges" arguments: nil toRep: rep];
	int width = [costRep pixelsWide];
	int height = [costRep pixelsHigh];
	int costRowBytes = [costRep bytesPerRow];
	void *costPtr = [costRep bitmapData];
	int repRowBytes = [rep bytesPerRow];
	void *repPtr = [rep bitmapData];
	
	int x, y;
	for( y = 0; y < height; y++ )
		for( x = 0; x < width; x++ )
		{
			struct Pixel *p = costPtr + x * sizeof( struct Pixel ) + y * costRowBytes;
			if( !p->r && !p->g && !p->b )
			{
				p->r = 1;
				p->g = 1;
				p->b = 1;
			}
		}
	BOOL foundZero = NO;
	for( y = 0; y < height; y++ )
		for( x = 0; x < width; x++ )
		{
			struct Pixel *p = repPtr + x * sizeof( struct Pixel ) + y * repRowBytes;
			if( !p->r && !p->g && !p->b )
			{
				struct Pixel *p2 = costPtr + x * sizeof( struct Pixel ) + y * costRowBytes;
				*p2 = *p;
				foundZero = YES;
			}
		}
	if( !foundZero )
		return nil;
	
	// note that costs are offset by one vertically, so that row 0 is actually
	// the image's row -1, containing all zeroes
	float *costs = malloc( width * (height + 1) * sizeof( *costs ) );
	bzero( costs, width * sizeof( *costs ) );
	
	// fill out the costs map
	for( y = 0; y < height; y++ )
	{
		for( x = 0; x < width; x++ )
		{
			struct Pixel *p = costPtr + x * sizeof( struct Pixel ) + y * costRowBytes;
			int pixelCost = p->r + p->g + p->b;
			if( pixelCost == 0 )
				pixelCost = -1000000;
			
			int costIndex = x + y * width;
			float bestCost = costs[costIndex];
			if( x > 0 )
				bestCost = MIN( bestCost, costs[costIndex - 1] );
			if( x < width - 1 )
				bestCost = MIN( bestCost, costs[costIndex + 1] );
			costs[costIndex + width] = bestCost + pixelCost;
		}
	}
	
	// generate a path, bottom up
	int *values = malloc( height * sizeof( *values ) );
	
	// first, find the minimum point at the very bottom
	float bestBottom = 1e50;
	for( x = 0; x < width; x++ )
	{
		float cost = costs[x + height * width];
		if( cost < bestBottom )
		{
			bestBottom = cost;
			values[height - 1] = x;
		}
	}
	
	// now find minimum points after that
	for( y = height - 1; y > 0; y-- )
	{
		int x = values[y];
		int costIndex = x + y * width;
		float bestCost = costs[costIndex];
		int bestValue = x;
		if( x > 0 && costs[costIndex - 1] < bestCost )
		{
			bestCost = costs[costIndex - 1];
			bestValue = x - 1;
		}
		if( x < width - 1 && costs[costIndex + 1] < bestCost )
		{
			bestCost = costs[costIndex + 1];
			bestValue = x + 1;
		}
		
		values[y - 1] = bestValue;
	}
	
	free( costs );
	
	NSBitmapImageRep *returnRep = [self _repBySlicingValues: values fromRep: (NSBitmapImageRep *)rep];
	free( values );
	return returnRep;
}

- (void)_setImage
{
	[mImageView setRep: mRep];
}

- (void)_updateImage
{
	NSBitmapImageRep *newRep = [self _shrinkRep: mRep];
	if( newRep )
	{
		[mRep release];
		mRep = [newRep retain];
		
		[self _setImage];
	}
	else
	{
		[mTimer invalidate];
		[mTimer release];
		mTimer = nil;
	}
}

- (void)awakeFromNib
{
	NSOpenPanel *p = [NSOpenPanel openPanel];
	[p runModalForTypes: nil];
	NSImage *image = [[NSImage alloc] initWithContentsOfFile: [p filename]];
	[image setScalesWhenResized: YES];
	//[image setSize: NSMakeSize( 640, 480 )];
	mRep = [[self _repForImage: image] retain];
	[image release];
	
	[self _setImage];
	[mImageView setDelegate: self];
}

- (void)mouseDownAtPoint: (NSPoint)p
{
	mDownPoint = p;
}

- (void)mouseUpAtPoint: (NSPoint)p
{
	if( mTimer )
		return;
	
	float minx = MIN( p.x, mDownPoint.x );
	float maxx = MAX( p.x, mDownPoint.x );
	float miny = MIN( p.y, mDownPoint.y );
	float maxy = MAX( p.y, mDownPoint.y );
	
	NSRect r = NSMakeRect( minx, miny, maxx - minx, maxy - miny );
	r.size.width = MAX( r.size.width, 1 );
	r.size.height = MAX( r.size.height, 1 );
	
	int width = [mRep pixelsWide];
	int height = [mRep pixelsHigh];
	int rowbytes = [mRep bytesPerRow];
	void *ptr = [mRep bitmapData];
	
	NSRect repRect = { NSZeroPoint, { width, height } };
	r = NSIntersectionRect( r, repRect );
	
	int x, y;
	for( y = NSMinY( r ); y < NSMaxY( r ); y++ )
		for( x = NSMinX( r ); x < NSMaxX( r ); x++ )
		{
			struct Pixel *p = ptr + x * sizeof( struct Pixel ) + y * rowbytes;
			p->r = 0;
			p->g = 0;
			p->b = 0;
		}
	
	[mImageView setNeedsDisplay: YES];
	
	mTimer = [[NSTimer scheduledTimerWithTimeInterval: 0 target: self selector: @selector( _updateImage ) userInfo: nil repeats: YES] retain];
}

@end