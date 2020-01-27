SHELL=/bin/bash

# Parameters that we must pass to make
VERSION=$(VERSION)
ARCH=$(ARCH)
VIRTIO_WIN_DRIVERS_PATH=$(VIRTIO_WIN_DRIVERS_PATH)

NAME=virtio-win-guest-tools-installer
ARCHIVE=$(NAME)-$(VERSION).tar.gz
# Location of installed RPMS that we package:
# ovirt-guest-agent-windows.rpm
# mingw32\64-spice-vdagent.rpm
# wix311-binaries
OVIRTGA_PATH=/usr/share/ovirt-guest-agent-windows
VDA32BIN=/usr/i686-w64-mingw32/sys-root/mingw/bin/
VDA64BIN=/usr/x86_64-w64-mingw32/sys-root/mingw/bin/
WIX_BINARIES_FILES=/usr/share/wix-toolset-binaries

# Project Paths #
VDAGENT_LINK=$(CURDIR)/vdagent
WIX_BINARIES_LINK=$(CURDIR)/wix311-binaries
SSO_PATH=$(CURDIR)/3rdParty/SSO
OVIRTGA_LINK=$(CURDIR)/ovirt-guest-agent

# Windows Paths 
VIRTIO_WIN_PATH=$(shell winepath -w $(VIRTIO_WIN_DRIVERS_PATH)|sed 's|\\|\\\\\\\\|g')
OVIRT_GA_WIN_PATH=$(shell winepath -w $(OVIRTGA_LINK)|sed 's|\\|\\\\\\\\|g')
VDAGENT_WIN_PATH=$(shell winepath -w $(VDAGENT_LINK)|sed 's|\\|\\\\\\\\|g')
SSO_WIN_PATH=$(shell winepath -w $(SSO_PATH)|sed 's|\\|\\\\\\\\|g')
WIX_BINARIES_WIN_PATH=$(shell winepath -w $(WIX_BINARIES_LINK)|sed 's|\\|\\\\\\\\|g')
INSTALLER_WIN_PATH=$(shell winepath -w $(CURDIR)/installer|sed 's|\\|\\\\\\\\|g')
#Package names for manifest
VIRTIO_WIN_VER=$(shell rpm -q virtio-win)
OVIRT_GA_WINDOWS_VER=$(shell rpm -q ovirt-guest-agent-windows)
SPICE_AGENT_VER=$(shell rpm -q mingw32-spice-vdagent)
WIX_TOOLSET_VER=$(shell rpm -q wix-toolset-binaries)


GENERATED = \
	installer/constants.wxi \
	installer/build_args/candle_argsx64.txt \
	installer/build_args/candle_argsx86.txt \
	installer/build_args/light_argsx64.txt \
	installer/build_args/light_argsx86.txt \
	$(NULL)


all: init-files $(GENERATED) create-installer


init-files: ovirt-guest-agent vdagent wix manifest


ovirt-guest-agent: $(OVIRTGA_PATH)
	ln -s "$(OVIRTGA_PATH)" "$(OVIRTGA_LINK)"


vdagent: $(VDA32BIN) $(VDA64BIN)
	mkdir -p $(VDAGENT_LINK)
	ln -s "$(VDA32BIN)" $(VDAGENT_LINK)/x86
	ln -s "$(VDA64BIN)" $(VDAGENT_LINK)/x64


wix: $(WIX_BINARIES_FILES)
	ln -s "$(WIX_BINARIES_FILES)" $(WIX_BINARIES_LINK)


manifest:
	sed \
	-e "s|@@VIRTIO_WIN@@|${VIRTIO_WIN_VER}|g" \
	-e "s|@@OVIRT_GA_WINDOWS@@|${OVIRT_GA_WINDOWS_VER}|g" \
	-e "s|@@SPICE_AGENT@@|${SPICE_AGENT_VER}|g" \
	-e "s|@@WIX_TOOLSET@@|${WIX_TOOLSET_VER}|g" \
	-i manifest.txt


create-installer: $(GENERATED) wix vdagent ovirt-guest-agent
	pushd installer/ ;\
	wine cmd.exe /c "$(WIX_BINARIES_LINK)/candle.exe @build_args/candle_args$(ARCH).txt" ;\
	wine cmd.exe /c "$(WIX_BINARIES_LINK)/light.exe -sval @build_args/light_args$(ARCH).txt" ;\
	rm -rf wixobjx*; \
	popd


test:
	python3 -m pytest test/test.py


clean:
	rm -rf exported-artifacts tmp
	rm -rf .wine .local .config .cache
	rm -f wix311-binaries.zip
	rm -rf *.tar.gz
	rm -rf $(VDAGENT_LINK)
	rm -rf $(WIX_BINARIES_LINK)
	rm -f $(OVIRTGA_LINK)
	rm -f $(GENERATED)


.SUFFIXES:
.SUFFIXES: .in 


.in:
	@echo $<
	sed \
	-e "s|@@VIRTIO-WIN-PATH@@|${VIRTIO_WIN_PATH}|g" \
	-e "s|@@OVIRT-GA-PATH@@|${OVIRT_GA_WIN_PATH}|g" \
	-e "s|@@VDAGENT-WIN-PATH@@|${VDAGENT_WIN_PATH}|g" \
	-e "s|@@SSO-WIN-PATH@@|${SSO_WIN_PATH}|g" \
	-e "s|@@WIX_BIN_PATH@@|${WIX_BINARIES_WIN_PATH}\\\\|g" \
	-e "s|@@INSTALLER_PATH@@|${INSTALLER_WIN_PATH}|g" \
	-e "s|@@VERSION@@|${VERSION}|g" \
	$< > $@


dist:
	tar -cvf "$(ARCHIVE)" --owner=root --group=root ./*


.PHONY : all init-files ovirt-guest-agent vdagent wix manifest create-installer dist test
