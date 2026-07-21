#include "SiftPrivilegedShim.h"

#include <string.h>

OSStatus SiftExecuteSFLTool(
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
