#!/bin/bash

year=`date '+%Y'`
month=`date '+%m'`

hugo new post/$year/$month/$1
