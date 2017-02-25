#!/bin/bash

year=`date '+%Y'`
month=`date '+%m'`

mkdir -p $year/$month

hugo new post/$year/$month/$1
