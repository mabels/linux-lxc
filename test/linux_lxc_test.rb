
require 'rubygems'

begin
  require 'pryx'
rescue Exception => e
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
    @temp_dir = Dir.mktmpdir
    @lxc_config = File.join(@temp_dir, 'lxc.config')
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
    @lxc_ubuntu_common_conf = File.join(@temp_dir, 'ubuntu.common.conf')
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

lxc.include = #{File.join(@temp_dir, 'empty.conf.d')}
lxc.include = #{File.join(@temp_dir, 'common.conf.d')}
SAMPLE
    FileUtils.mkdir_p File.join(@temp_dir, 'empty.conf.d')
    FileUtils.mkdir_p File.join(@temp_dir, 'common.conf.d')
    @lxc_common_conf_d_wildcard = File.join(@temp_dir, 'common.conf.d', 'wildcard.conf')
    File.write(@lxc_common_conf_d_wildcard, <<SAMPLE)
lxc.wildcard.loaded = true
lxc.hook.mount = /usr/share/lxcfs/lxc.mount.hook
lxc.hook.post-stop = /usr/share/lxcfs/lxc.reboot.hook
SAMPLE
  end

  def teardown
    FileUtils.remove_entry_secure @temp_dir
  end

  def test_reader
    lxc = Linux::Lxc.parse(@lxc_config)

    assert_equal lxc.get('lxc').length, 43
    assert_equal lxc.get('lxc.network').length, 4
    assert_equal lxc.get('lxc.network.hwaddr').length, 1
    assert_equal lxc.get('lxc.network.murks'), nil

    assert_equal lxc.get('lxc.wildcard.loaded').values[0], 'true'
    assert_equal lxc.get('lxc.wildcard.loaded')[0].file, @lxc_common_conf_d_wildcard
    assert_equal lxc.get('lxc.wildcard.loaded')[0].line, 1

    assert_equal lxc.get('lxc.cgroup.devices.allow').values[4], 'c 5:0 rwm'
    assert_equal lxc.get('lxc.cgroup.devices.allow')[4].file, @lxc_ubuntu_common_conf
    assert_equal lxc.get('lxc.cgroup.devices.allow')[4].line, 48

    assert_equal lxc.get('lxc.network.hwaddr').values, ['00:16:3e:67:03:4a']
    assert_equal lxc.get('lxc.network.hwaddr').first.file, @lxc_config
    assert_equal lxc.get('lxc.network.hwaddr').first.line, 18
  end

  def test_from_scratch
    lxc = Linux::Lxc.file(File.join(@temp_dir, 'base.f'))
    lxc.add('# base meno')
    lxc.add('lxc.cgroup.devices.allow', 'meno')
    incl = Linux::Lxc.file(File.join(@temp_dir, 'incl.f.conf'))
    lxc.add('lxc.include', incl)
    incl.add('# include meno')
    incl.add('lxc.network.hwaddr', '00:16:3e:67:03:4a')

    empty_d = Linux::Lxc.directory(File.join(@temp_dir, 'scratch.empty.d'))
    lxc.add('lxc.include', empty_d)

    scratch_d = Linux::Lxc.directory(File.join(@temp_dir, 'scratch.d'))
    lxc.add('lxc.include', scratch_d)


    scratch_file = scratch_d.add_file(File.join(@temp_dir, 'scratch.d', 'file.conf'))
    scratch_file.add('# include scratch')
    scratch_file.add('lxc.scratch_file', 'it_is_scratch_file')
    lxc.write

    lxc_read = Linux::Lxc.parse(lxc.file)
    assert_equal lxc_read.get('#').length, 3
    assert_equal lxc_read.get('lxc.cgroup.devices.allow').values, ['meno']
    assert_equal lxc_read.get('lxc.cgroup.devices.allow').first.file, lxc.file
    assert_equal lxc_read.get('lxc.cgroup.devices.allow').first.line, 2

    assert_equal lxc_read.get('lxc.network.hwaddr').values, ['00:16:3e:67:03:4a']
    assert_equal lxc_read.get('lxc.network.hwaddr').first.file, incl.file
    assert_equal lxc_read.get('lxc.network.hwaddr').first.line, 2

    assert_equal lxc_read.get('lxc.scratch_file').values, ['it_is_scratch_file']
    assert_equal lxc_read.get('lxc.scratch_file').first.file, scratch_file.file
    assert_equal lxc_read.get('lxc.scratch_file').first.line, 2

    assert_equal lxc_read.index.files.length, 3

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
    assert_equal lxc.get('#')[45].to_s, '# lxc.network.link = lxcbr0'
    assert_equal lxc.get('lxc.network'), nil
    lxc.index.files.values.each do |file|
      file.real_fname = ::File.join(::File.dirname(file.file), "-.#{::File.basename(file.file)}")
    end
    lxc.write
    l2 = Linux::Lxc.parse(::File.join(::File.dirname(@lxc_config), "-.#{::File.basename(@lxc_config)}"))
    assert_equal l2.lines.first.key, "#"
    assert_equal l2.lines.first.value, "# Template used to create this container: /usr/share/lxc/templates/lxc-ubuntu"

    lxc.index.files.values.each do |file|
      file.file = ::File.join(::File.dirname(file.file), "+.#{::File.basename(file.file)}")
    end
    lxc.write
    l3 = Linux::Lxc.parse(::File.join(::File.dirname(@lxc_config), "+.#{::File.basename(@lxc_config)}"))
    assert_equal l3.lines.first.key, "#"
    assert_equal l3.lines.first.value, "# Template used to create this container: /usr/share/lxc/templates/lxc-ubuntu"
    assert_equal ::File.basename(l3.index.files.values[1].file), "+.ubuntu.common.conf"
    assert_equal l3.index.files.values[1].lines.first.key, "#"
    assert_equal l3.index.files.values[1].lines.first.value, "# Default pivot location"

  end

  def test_real_fname
    lxc = Linux::Lxc.file(File.join(@temp_dir, 'real_name'))
    lxc.add('# base meno')
    lxc.add('lxc.cgroup.devices.allow', 'meno')
    lxc.write
    lxc.real_fname = File.join(@temp_dir, 'test_name')
    incl = Linux::Lxc.file(File.join(@temp_dir, 'test_incl'))
    incl.real_fname = File.join(@temp_dir, 'real_incl')
    lxc.add('lxc.include', incl)
    incl.add('# include meno')
    incl.add('lxc.network.hwaddr', '00:16:3e:67:03:4a')
    lxc.write
    assert_equal File.exist?(File.join(@temp_dir, 'test_name')), true
    assert_equal File.exist?(File.join(@temp_dir, 'real_name')), true
    assert_equal File.exist?(File.join(@temp_dir, 'real_incl')), true
    assert_equal File.exist?(File.join(@temp_dir, 'test_incl')), false
    #    assert_raise do #Fails, no Exceptions are raised
    begin
      lxc = Linux::Lxc.parse(File.join(@temp_dir, 'test_name'))
      assert_equal 'Doof', 'Darf nie passieren'
    rescue Exception => e
      assert_equal e.instance_of?(Errno::ENOENT), true
      assert_equal File.basename(e.message), 'test_incl'
    end
    #    end
  end

  def test_lines
    lxc = Linux::Lxc.parse(@lxc_config)
    cnt = 0
    lxc.all_lines { |_line| cnt += 1 }
    assert_equal cnt, 98
  end

  def test_files
    lxc = Linux::Lxc.parse(@lxc_config)
    files = lxc.index.files.keys
    assert_equal files[0], @lxc_config
    assert_equal files[1], @lxc_ubuntu_common_conf
    assert_equal files[2], @lxc_common_conf_d_wildcard
    assert_equal files.length, 3
  end

  def test_write
    lxc = Linux::Lxc.parse(@lxc_config)
    inc_file = "#{lxc.get('lxc.cgroup.devices.allow').first.lxc.file}.new"
    lxc.get('lxc.cgroup.devices.allow').first.lxc.file = inc_file
    lxc.get('lxc.cgroup.devices.allow')[5].value = 'meno'
    assert_equal lxc.get('lxc.cgroup.devices.allow').values[5], 'meno'

    lxc.get('lxc.network.hwaddr').first.value = 'construqt'
    assert_equal lxc.get('lxc.network.hwaddr').values, ['construqt']

    assert_equal lxc.get('lxc.network.hwaddr').find{|i| i.value == 'construqt'}.value, 'construqt'
    lxc.write

    lxc_read = Linux::Lxc.parse(lxc.file)
    assert_equal lxc_read.get('lxc.cgroup.devices.allow').values[5], 'meno'
    assert_equal lxc_read.get('lxc.cgroup.devices.allow')[5].file, inc_file
    assert_equal lxc_read.get('lxc.cgroup.devices.allow')[5].line, 49

    assert_equal lxc_read.get('lxc.network.hwaddr').values, ['construqt']
    assert_equal lxc_read.get('lxc.network.hwaddr').first.file, lxc.file
    assert_equal lxc_read.get('lxc.network.hwaddr').first.line, 18
  end

  def test_numeric_prefix_order
    assert_equal Linux::Lxc.numeric_prefix_order(["100_a", "1_b", "34d"]), ["1_b","34d","100_a"]
    assert_equal Linux::Lxc.numeric_prefix_order(["1_c", "1_a", "1a"]), ["1_a","1_c","1a"]
    assert_equal Linux::Lxc.numeric_prefix_order(["000100_a", "000001_b", "034d"]), ["000001_b","034d","000100_a"]
    assert_equal Linux::Lxc.numeric_prefix_order(["foo","100_a", "000001_b", "bar", "34d"]), ["000001_b","34d","100_a","bar", "foo"]
    assert_equal Linux::Lxc.numeric_prefix_order(["foo","yyy", "bar"]), ["bar", "foo", "yyy"]
  end
end
