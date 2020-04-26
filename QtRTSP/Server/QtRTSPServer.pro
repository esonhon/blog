QT += core gui
QT += multimedia

greaterThan(QT_MAJOR_VERSION, 4): QT += widgets

CONFIG += c++11

DEFINES += NO_OPENSSL

# The following define makes your compiler emit warnings if you use
# any Qt feature that has been marked deprecated (the exact warnings
# depend on your compiler). Please consult the documentation of the
# deprecated API in order to know how to port your code away from it.
DEFINES += QT_DEPRECATED_WARNINGS

# You can also make your code fail to compile if it uses deprecated APIs.
# In order to do so, uncomment the following line.
# You can also select to disable deprecated APIs only up to a certain version of Qt.
#DEFINES += QT_DISABLE_DEPRECATED_BEFORE=0x060000    # disables all the APIs deprecated before Qt 6.0.0


X264_PATH = $$PWD/../libs/x264

INCLUDEPATH = $$X264_PATH/include

LIBS += $$X264_PATH/lib/libx264.dll.a

x264dll.files += $$X264_PATH/bin/libx264-157.dll
x264dll.path = $$PWD

!exists($$PWD/libx264-157.dll) : INSTALLS = x264dll


LIVE555_PATH = $$PWD/../libs/LIVE555

INCLUDEPATH += $$LIVE555_PATH/BasicUsageEnvironment/include
INCLUDEPATH += $$LIVE555_PATH/groupsock/include
INCLUDEPATH += $$LIVE555_PATH/liveMedia/include
INCLUDEPATH += $$LIVE555_PATH/UsageEnvironment/include

win32 {
    CONFIG(debug, debug|release) {
        BUILD_MODE = Debug
    } else {
        BUILD_MODE = Release
    }
}

LIBS += $$LIVE555_PATH/BasicUsageEnvironment/$$BUILD_MODE/BasicUsageEnvironment.lib
LIBS += $$LIVE555_PATH/UsageEnvironment/$$BUILD_MODE/UsageEnvironment.lib
LIBS += $$LIVE555_PATH/groupsock/$$BUILD_MODE/groupsock.lib
LIBS += $$LIVE555_PATH/liveMedia/$$BUILD_MODE/liveMedia.lib

PRE_TARGETDEPS += $$LIVE555_PATH/BasicUsageEnvironment/$$BUILD_MODE/BasicUsageEnvironment.lib
PRE_TARGETDEPS += $$LIVE555_PATH/UsageEnvironment/$$BUILD_MODE/UsageEnvironment.lib
PRE_TARGETDEPS += $$LIVE555_PATH/groupsock/$$BUILD_MODE/groupsock.lib
PRE_TARGETDEPS += $$LIVE555_PATH/liveMedia/$$BUILD_MODE/liveMedia.lib

LIBS += Ws2_32.lib


SOURCES += \
    CameraFrameGrabber.cpp \
    CameraH264Source.cpp \
    CameraRTSPServer.cpp \
    H264MediaSubsession.cpp \
    H264NalFactory.cpp \
    X264Encoder.cpp \
    main.cpp \
    ImageWidget.cpp \
    rgb2yuv.c

HEADERS += \
    CameraFrameGrabber.h \
    CameraH264Source.h \
    CameraRTSPServer.h \
    H264Encoder.h \
    H264MediaSubsession.h \
    H264NalFactory.h \
    ImageWidget.h \
    X264Encoder.h \
    rgb2yuv.h


# Default rules for deployment.
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target

