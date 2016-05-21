//
//  IMPExif.h
//  IMProcessing
//
//  Created by denis svinarchuk on 21.05.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

#ifndef IMPExif_h
#define IMPExif_h

typedef enum  {
    //
    // Exif codes, F is example
    //
    // 1        2       3      4         5            6           7          8
    //
    // 888888  888888      88  88      8888888888  88                  88  8888888888
    // 88          88      88  88      88  88      88  88          88  88      88  88
    // 8888      8888    8888  8888    88          8888888888  8888888888          88
    // 88          88      88  88
    // 88          88  888888  888888
    IMPExifOrientationUp                      = 1,
    IMPExifOrientationHorizontalFlipped       = 2,
    IMPExifOrientationLeft180                 = 3,
    IMPExifOrientationVerticalFlipped         = 4,
    IMPExifOrientationLeft90VertcalFlipped    = 5,
    IMPExifOrientationLeft90                  = 6,
    IMPExifOrientationLeft90HorizontalFlipped = 7,
    IMPExifOrientationRight90                 = 8,
}IMPExifOrientation;


#endif /* IMPExif_h */
