# pngohsh
Tool to compute and write the PNG original hash (`ohSH`) chunk.

PNG files are often ran through a crushers/optimizers such as `pngcrush` or `optipng`. The "brute force" settings of these tools can take several minutes for large PNGs. By using the `ohSH` chunk, we can skip unnecessary crushes. 

# Overview

Assume we have two files:

1. An uncrushed PNG file, freshly exported from our graphics design program. We may have used an "Export All" command; thus, this file may be identical to our last export.

2. A crushed PNG file on our web server.

Is it necessary to run the crusher/optimizer on File 1? Will we end up with File 2?

# Methodology

1. Compute the ohSH chunk of the new file:
> `pngohsh compute new.png`

2. Read the ohSH chunk of the old file:
> `pngohsh read old.png`

3. If equal, we are done. `*tosses confetti*`

4. If not equal, run `pngcrush`, `optipng`, `pngquant`, etc. Store the result to `new_crushed.png`.

5. Save the ohSH chunk from Step 1 to the crushed file:
> `pngohsh write new_crushed.png 3432ce91ecc28194f0f41ec4b696f8352d73df29`

6. Overwrite `old.png` with `new_crushed.png`:
> `cp new_crushed.png old.png`

# Specification

The `ohSH` chunk is build-system specific and should represent a hash of the visible image. Portability between build systems / OS versions is not a requirement.

This tool uses macOS's CoreGraphics and hashes the following components of the PNG file:

1. Width
2. Height
3. Color depth
4. bytesPerRow/CGBitmapInfo
5. Color space
6. Pre-multiplied image data
