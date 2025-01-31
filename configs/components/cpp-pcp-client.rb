component 'cpp-pcp-client' do |pkg, settings, platform|
  pkg.load_from_json('configs/components/cpp-pcp-client.json')

  boost_static_flag = ''
  cmake = '/opt/pl-build-tools/bin/cmake'
  toolchain = '-DCMAKE_TOOLCHAIN_FILE=/opt/pl-build-tools/pl-build-toolchain.cmake'
  make = platform[:make]

  if platform.is_windows?
    pkg.environment 'PATH', "$(shell cygpath -u #{settings[:gcc_bindir]}):$(shell cygpath -u #{settings[:bindir]}):/cygdrive/c/Windows/system32:/cygdrive/c/Windows:/cygdrive/c/Windows/System32/WindowsPowerShell/v1.0"
  else
    pkg.environment 'PATH', "#{settings[:bindir]}:/opt/pl-build-tools/bin:$(PATH)"
  end

  if settings[:system_openssl]
    pkg.build_requires 'openssl-devel'
  else
    pkg.build_requires 'puppet-runtime' # Provides openssl
  end
  pkg.build_requires 'leatherman'

  if platform.is_aix?
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/aix/#{platform.os_version}/ppc/pl-gcc-5.2.0-11.aix#{platform.os_version}.ppc.rpm"
    pkg.build_requires "http://pl-build-tools.delivery.puppetlabs.net/aix/#{platform.os_version}/ppc/pl-cmake-3.2.3-2.aix#{platform.os_version}.ppc.rpm"
    # This should be moved to the toolchain file
    platform_flags = '-DCMAKE_SHARED_LINKER_FLAGS="-Wl,-bbigtoc"'
  elsif platform.is_macos?
    cmake = '/usr/local/bin/cmake'
    special_flags = "-DCMAKE_CXX_FLAGS='#{settings[:cflags]}' -DENABLE_CXX_WERROR=OFF"
    toolchain = ''
    boost_static_flag = '-DBOOST_STATIC=OFF'
    if platform.is_cross_compiled?
      pkg.environment 'CXX', 'clang++ -target arm64-apple-macos11' if platform.name =~ /osx-11/
      pkg.environment 'CXX', 'clang++ -target arm64-apple-macos12' if platform.name =~ /osx-12/
    end
  elsif platform.is_cross_compiled_linux?
    cmake = '/opt/pl-build-tools/bin/cmake'
    toolchain = "-DCMAKE_TOOLCHAIN_FILE=/opt/pl-build-tools/#{settings[:platform_triple]}/pl-build-toolchain.cmake"
  elsif platform.is_solaris?
    cmake = "/opt/pl-build-tools/i386-pc-solaris2.#{platform.os_version}/bin/cmake"
    toolchain = "-DCMAKE_TOOLCHAIN_FILE=/opt/pl-build-tools/#{settings[:platform_triple]}/pl-build-toolchain.cmake"
  elsif platform.is_windows?
    make = "#{settings[:gcc_root]}/bin/mingw32-make"
    pkg.environment 'CYGWIN', settings[:cygwin]

    cmake = 'C:/ProgramData/chocolatey/bin/cmake.exe -G "MinGW Makefiles"'
    toolchain = "-DCMAKE_TOOLCHAIN_FILE=#{settings[:tools_root]}/pl-build-toolchain.cmake"
  elsif platform.name =~ /el-[67]|redhatfips-7|sles-12|ubuntu-18.04-amd64/
    # use default that is pl-build-tools
  else
    # These platforms use the default OS toolchain, rather than pl-build-tools
    pkg.environment 'CPPFLAGS', settings[:cppflags]
    pkg.environment 'LDFLAGS', settings[:ldflags]
    cmake = 'cmake'
    toolchain = ''
    platform_flags = "-DCMAKE_CXX_FLAGS='#{settings[:cflags]} -Wimplicit-fallthrough=0'"
    special_flags = ' -DENABLE_CXX_WERROR=OFF'
  end

  # Boost_NO_BOOST_CMAKE=ON was added while upgrading to boost
  # 1.73 for PA-3244. https://cmake.org/cmake/help/v3.0/module/FindBoost.html#boost-cmake
  # describes the setting itself (and what we are disabling). It
  # may make sense in the future to remove this cmake parameter and
  # actually make the boost build work with boost's own cmake
  # helpers. But for now disabling boost's cmake helpers allow us
  # to upgrade boost with minimal changes.
  #                                  - Sean P. McDonald 5/19/2020
  pkg.configure do
    [
      "#{cmake} \
      #{toolchain} \
      #{platform_flags} \
          -DLEATHERMAN_GETTEXT=ON \
          -DCMAKE_VERBOSE_MAKEFILE=ON \
          -DCMAKE_PREFIX_PATH=#{settings[:prefix]} \
          -DCMAKE_INSTALL_PREFIX=#{settings[:prefix]} \
          -DCMAKE_INSTALL_RPATH=#{settings[:libdir]} \
          -DCMAKE_SYSTEM_PREFIX_PATH=#{settings[:prefix]} \
          -DBoost_NO_BOOST_CMAKE=ON \
          #{special_flags} \
          #{boost_static_flag} \
          ."
    ]
  end

  pkg.build do
    ["#{make} -j$(shell expr $(shell #{platform[:num_cores]}) + 1)"]
  end

  pkg.install do
    ["#{make} -j$(shell expr $(shell #{platform[:num_cores]}) + 1) install"]
  end
end
