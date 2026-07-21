#ifndef SiftPrivilegedShim_h
#define SiftPrivilegedShim_h

#include <Security/Authorization.h>
#include <stdio.h>

OSStatus SiftExecuteSFLTool(
    AuthorizationRef authorization,
    const char *action,
    FILE **communicationsPipe
);

#endif
