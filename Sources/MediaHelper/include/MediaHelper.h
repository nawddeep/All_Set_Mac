#ifndef MEDIAHELPER_H
#define MEDIAHELPER_H

/// Entry point called from perl through DynaLoader, which passes the perl
/// interpreter and CV pointers (both unused). Never returns.
__attribute__((visibility("default")))
void allset_media_run(void *perlInterpreter, void *cv);

#endif
