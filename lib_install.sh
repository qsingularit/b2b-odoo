#!/bin/bash

set -e

tar uvf test.tar usr/lib/python3/dist-packages/reportlab/graphics
tar uvf test.tar usr/lib/x86_64-linux-gnu/libX11.so*
tar uvf test.tar usr/share/lintian/overrides/libx11* 

exit 0
