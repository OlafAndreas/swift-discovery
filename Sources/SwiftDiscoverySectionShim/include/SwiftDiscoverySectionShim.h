#ifndef SWIFT_DISCOVERY_SECTION_SHIM_H
#define SWIFT_DISCOVERY_SECTION_SHIM_H

/// Bounds of the `swift5_discov` section in the image this shim is linked into.
/// Both return NULL when the object format is not ELF or the section is absent.
const void *swiftdiscovery_elf_section_start(void);
const void *swiftdiscovery_elf_section_stop(void);

#endif
