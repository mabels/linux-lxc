
require 'rubygems'

begin
  require 'pry'
rescue
  # it would be cool but-:)
end

require 'fileutils'

require 'rubygems'
require 'test/unit'

require 'tempfile'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'linux/lxc'

class LinuxLxcTest < Test::Unit::TestCase
  def setup
    @temp_dir =  Dir.mktmpdir
    @lxc_config = File.join(@temp_dir, "lxc.config")
    File.write(@lxc_config, <<SAMPLE)
# Template used to create this container: /usr/share/lxc/templates/lxc-ubuntu
# Parameters passed to the template:
# For additional config options, please look at lxc.container.conf(5)

# Common configuration
lxc.include = #{@temp_dir}/ubuntu.common.conf

# Container specific configuration
lxc.rootfs = /var/lib/lxc/border-eth0/rootfs
lxc.mount = /var/lib/lxc/border-eth0/fstab
lxc.utsname = border-eth0
lxc.arch = amd64

# Network configuration
lxc.network.type = veth
lxc.network.flags = up
lxc.network.link = lxcbr0
lxc.network.hwaddr = 00:16:3e:67:03:4a
SAMPLE
    @lxc_ubuntu_common_conf = File.join(@temp_dir, "ubuntu.common.conf")
    File.write(@lxc_ubuntu_common_conf, <<SAMPLE)
# Default pivot location
lxc.pivotdir = lxc_putold

# Default mount entries
lxc.mount.entry = proc proc proc nodev,noexec,nosuid 0 0
lxc.mount.entry = sysfs sys sysfs defaults 0 0
lxc.mount.entry = /sys/fs/fuse/connections sys/fs/fuse/connections none bind,optional 0 0
lxc.mount.entry = /sys/kernel/debug sys/kernel/debug none bind,optional 0 0
lxc.mount.entry = /sys/kernel/security sys/kernel/security none bind,optional 0 0
lxc.mount.entry = /sys/fs/pstore sys/fs/pstore none bind,optional 0 0

# Default console settings
lxc.devttydir = lxc
lxc.tty = 4
lxc.pts = 1024

# Default capabilities
lxc.cap.drop = sys_module mac_admin mac_override sys_time

# When using LXC with apparmor, the container will be confined by default.
# If you wish for it to instead run unconfined, copy the following line
# (uncommented) to the container's configuration file.
#lxc.aa_profile = unconfined

# To support container nesting on an Ubuntu host while retaining most of
# apparmor's added security, use the following two lines instead.
#lxc.aa_profile = lxc-container-default-with-nesting
#lxc.mount.auto = cgroup:mixed

# Uncomment the following line to autodetect squid-deb-proxy configuration on the
# host and forward it to the guest at start time.
#lxc.hook.pre-start = /usr/share/lxc/hooks/squid-deb-proxy-client

# If you wish to allow mounting block filesystems, then use the following
# line instead, and make sure to grant access to the block device and/or loop
# devices below in lxc.cgroup.devices.allow.
#lxc.aa_profile = lxc-container-default-with-mounting

# Default cgroup limits
lxc.cgroup.devices.deny = a
## Allow any mknod (but not using the node)
lxc.cgroup.devices.allow = c *:* m
lxc.cgroup.devices.allow = b *:* m
## /dev/null and zero
lxc.cgroup.devices.allow = c 1:3 rwm
lxc.cgroup.devices.allow = c 1:5 rwm
## consoles
lxc.cgroup.devices.allow = c 5:0 rwm
lxc.cgroup.devices.allow = c 5:1 rwm
## /dev/{,u}random
lxc.cgroup.devices.allow = c 1:8 rwm
lxc.cgroup.devices.allow = c 1:9 rwm
## /dev/pts/*
lxc.cgroup.devices.allow = c 5:2 rwm
lxc.cgroup.devices.allow = c 136:* rwm
## rtc
lxc.cgroup.devices.allow = c 254:0 rm
## fuse
lxc.cgroup.devices.allow = c 10:229 rwm
## tun
lxc.cgroup.devices.allow = c 10:200 rwm
## full
lxc.cgroup.devices.allow = c 1:7 rwm
## hpet
lxc.cgroup.devices.allow = c 10:228 rwm
## kvm
lxc.cgroup.devices.allow = c 10:232 rwm
## To use loop devices, copy the following line to the container's
## configuration file (uncommented).
#lxc.cgroup.devices.allow = b 7:* rwm

# Blacklist some syscalls which are not safe in privileged
# containers
lxc.seccomp = /usr/share/lxc/config/common.seccomp
SAMPLE
  end

  def teardown
    FileUtils.remove_entry_secure @temp_dir
  end

  def test_reader
    lxc = Linux::Lxc.parse(@lxc_config)

    assert_equal lxc.get('lxc').length, 38
    assert_equal lxc.get('lxc.network').length, 4
    assert_equal lxc.get('lxc.network.hwaddr').length, 1
    assert_equal lxc.get('lxc.network.murks'), nil

    assert_equal lxc.get('lxc.cgroup.devices.allow').values[4], 'c 5:0 rwm'
    assert_equal lxc.get('lxc.cgroup.devices.allow')[4].file, @lxc_ubuntu_common_conf
    assert_equal lxc.get('lxc.cgroup.devices.allow')[4].line, 48

    assert_equal lxc.get('lxc.network.hwaddr').values, ['00:16:3e:67:03:4a']
    assert_equal lxc.get('lxc.network.hwaddr').first.file, @lxc_config
    assert_equal lxc.get('lxc.network.hwaddr').first.line, 18
  end


  def test_from_scratch
    lxc = Linux::Lxc.new(File.join(@temp_dir, "base"))
    lxc.add("# base meno")
    lxc.add("lxc.cgroup.devices.allow", "meno")
    incl = Linux::Lxc.new(File.join(@temp_dir, "incl"))
    lxc.add("lxc.include", incl)
    incl.add("# include meno")
    incl.add("lxc.network.hwaddr", '00:16:3e:67:03:4a')
    lxc.write

    lxc_read = Linux::Lxc.parse(lxc.file)
    assert_equal lxc_read.get('#').length, 2
    assert_equal lxc_read.get('lxc.cgroup.devices.allow').values, ['meno']
    assert_equal lxc_read.get('lxc.cgroup.devices.allow').first.file, lxc.file
    assert_equal lxc_read.get('lxc.cgroup.devices.allow').first.line, 2

    assert_equal lxc_read.get('lxc.network.hwaddr').values, ['00:16:3e:67:03:4a']
    assert_equal lxc_read.get('lxc.network.hwaddr').first.file, incl.file
    assert_equal lxc_read.get('lxc.network.hwaddr').first.line, 2
  end

  def test_comment
    lxc = Linux::Lxc.parse(@lxc_config)
    assert_equal lxc.get('#').length, 42
    assert_equal lxc.get('lxc.cgroup.devices.allow').length, 16
    lxc.get('lxc.cgroup.devices.allow')[0].comment!
    assert_equal lxc.get('lxc.cgroup.devices.allow').length, 15
    assert_equal lxc.get('#').length, 43
    lxc.get('lxc.network').comment!
    assert_equal lxc.get('#').length, 47
    assert_equal lxc.get('lxc.network'), nil

  end

  def test_real_fname
    lxc = Linux::Lxc.new(File.join(@temp_dir, "real_name"))
    lxc.add("# base meno")
    lxc.add("lxc.cgroup.devices.allow", "meno")
    lxc.write
    lxc.real_fname = File.join(@temp_dir, "test_name")
    incl = Linux::Lxc.new(File.join(@temp_dir, "test_incl"))
    incl.real_fname = File.join(@temp_dir, "real_incl")
    lxc.add("lxc.include", incl)
    incl.add("# include meno")
    incl.add("lxc.network.hwaddr", '00:16:3e:67:03:4a')
    lxc.write
    assert_equal File.exists?(File.join(@temp_dir, "test_name")), true
    assert_equal File.exists?(File.join(@temp_dir, "real_name")), true
    assert_equal File.exists?(File.join(@temp_dir, "real_incl")), true
    assert_equal File.exists?(File.join(@temp_dir, "test_incl")), false
#    assert_raise do #Fails, no Exceptions are raised
    begin
      lxc = Linux::Lxc.parse(File.join(@temp_dir, "test_name"))
      assert_equal "Doof", "Darf nie passieren"
    rescue Exception => e
      assert_equal e.instance_of?(Errno::ENOENT), true
      assert_equal File.basename(e.message), "test_incl"
    end
#    end
  end

  def test_lines
    lxc = Linux::Lxc.parse(@lxc_config)
    cnt = 0
    lxc.all_lines{|line| cnt+=1 }
    assert_equal cnt, 92
  end

  def test_files
    lxc = Linux::Lxc.parse(@lxc_config)
    assert_equal lxc.files[0].value.file, @lxc_config
    assert_equal File.basename(lxc.files[1].value.file), "ubuntu.common.conf"
    assert_equal lxc.files.length, 2
  end

  def test_write
    lxc = Linux::Lxc.parse(@lxc_config)
    lxc.file = "#{@lxc_config}.new"
    inc_file = "#{lxc.get('lxc.cgroup.devices.allow').first.lxc.file}.new"
    lxc.get('lxc.cgroup.devices.allow').first.lxc.file = inc_file
    lxc.get('lxc.cgroup.devices.allow')[5].value='meno'
    assert_equal lxc.get('lxc.cgroup.devices.allow').values[5], 'meno'

    lxc.get('lxc.network.hwaddr').first.value='construqt'
    assert_equal lxc.get('lxc.network.hwaddr').values, ['construqt']

    lxc.write

    lxc_read = Linux::Lxc.parse(lxc.file)
    assert_equal lxc_read.get('lxc.cgroup.devices.allow').values[5], 'meno'
    assert_equal lxc_read.get('lxc.cgroup.devices.allow')[5].file, inc_file
    assert_equal lxc_read.get('lxc.cgroup.devices.allow')[5].line, 49

    assert_equal lxc_read.get('lxc.network.hwaddr').values, ['construqt']
    assert_equal lxc_read.get('lxc.network.hwaddr').first.file, lxc.file
    assert_equal lxc_read.get('lxc.network.hwaddr').first.line, 18

  end


end

