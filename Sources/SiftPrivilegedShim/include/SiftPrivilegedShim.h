#ifndef SiftPrivilegedShim_h
#define SiftPrivilegedShim_h

#include <Security/Authorization.h>
#include <stdio.h>

OSStatus SiftExecuteSFLTool(
    AuthorizationRef authorization,
    const char *action,
    FILE **communicationsPipe
);

OSStatus SiftReplaceHostsFile(
    AuthorizationRef authorization,
    const char *sourcePath,
    FILE **communicationsPipe
);

#endif
