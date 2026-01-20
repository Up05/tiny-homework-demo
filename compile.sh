#!/bin/sh
odin build . -debug -o:none -linker:lld && ./hourglass
