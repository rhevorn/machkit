#ifndef MachKitPrivilegedShim_h
#define MachKitPrivilegedShim_h

#include <Security/Authorization.h>
#include <stdio.h>

OSStatus MachKitExecuteSFLTool(
    AuthorizationRef authorization,
    const char *action,
    FILE **communicationsPipe
);

OSStatus MachKitReplaceHostsFile(
    AuthorizationRef authorization,
    const char *sourcePath,
    FILE **communicationsPipe
);

#endif
