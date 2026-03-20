ARCHS = arm64
TARGET = iphone:clang:latest:15.0
# THEOS_DEVICE_IP = iphoneX.local
THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk

TOOL_NAME = jbinit

jbinit_FILES = main.m
jbinit_CFLAGS = -fobjc-arc -Wno-unused-variable
jbinit_LDFLAGS = -framework MobileCoreServices
jbinit_CODESIGN_FLAGS = -Ipalehide.jbinit -Sentitlements.plist
jbinit_INSTALL_PATH = /usr/local/bin

include $(THEOS_MAKE_PATH)/tool.mk


after-install::
	install.exec " /usr/local/bin/jbinit"

clean::
	rm -rf ./packages/*

