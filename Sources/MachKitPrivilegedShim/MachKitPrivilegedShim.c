#include "MachKitPrivilegedShim.h"

#include <string.h>

OSStatus MachKitExecuteSFLTool(
    AuthorizationRef authorization,
    const char *action,
    FILE **communicationsPipe
) {
    if (action == NULL ||
        (strcmp(action, "dumpbtm") != 0 && strcmp(action, "resetbtm") != 0)) {
        return errAuthorizationDenied;
    }

    char *arguments[] = {(char *)action, NULL};

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    OSStatus status = AuthorizationExecuteWithPrivileges(
        authorization,
        "/usr/bin/sfltool",
        kAuthorizationFlagDefaults,
        arguments,
        communicationsPipe
    );
#pragma clang diagnostic pop

    return status;
}

OSStatus MachKitReplaceHostsFile(
    AuthorizationRef authorization,
    const char *sourcePath,
    FILE **communicationsPipe
) {
    if (sourcePath == NULL || sourcePath[0] != '/') {
        return errAuthorizationDenied;
    }

    char *arguments[] = {(char *)sourcePath, "/etc/hosts", NULL};

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    OSStatus status = AuthorizationExecuteWithPrivileges(
        authorization,
        "/bin/cp",
        kAuthorizationFlagDefaults,
        arguments,
        communicationsPipe
    );
#pragma clang diagnostic pop

    return status;
}
