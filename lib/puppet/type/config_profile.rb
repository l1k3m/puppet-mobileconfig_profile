# lib/puppet/type/config_profile.rb

require 'puppet/parameter/boolean'

Puppet::Type.newtype(:config_profile) do
  @doc = "Manage (install/remove) OS X configuration profile plists (mobileconfig) created with:
    Profile Manager part of OSX server :( -- (Settings_for_xx.mobileconfig)
      https://itunes.apple.com/us/app/os-x-server/id537441259?mt=12
      http://www.apple.com/support/osxserver/profilemanager/
    mcxToProfile by timsutton :) -- (Settings_for_xx_supplemental.mobileconfig)
      https://github.com/timsutton/mcxToProfile

    This resource type uses the profiles command (man profiles) and
    Can manage both user or device (system) profiles

    Installs/Updates profile when:
      no profile with identifier is installed
      profile (plist (mobileconfig)) file content changes

    You must manage getting the profile file on the system and give it's path
    **Autorequires:** file in path and user and user home, if possible

    Note:
      users must be logged into the GUI desktop and have finder/preferences running to load user profiles...
      Hence we check if logged in with who command before installing them
        - also console means desktop and not tty or ssh alone"

  ensurable do
    desc "What state the profile should be in. (installed/removed) This defaults to `installed`."

    newvalue(:present, :invalidate_refreshes => true) do
      provider.install
      nil # return nil so the event is autogenerated
    end

    newvalue(:absent) do
      provider.remove
      nil # return nil so the event is autogenerated
    end

    aliasvalue(:installed, :present)
    aliasvalue(:removed, :absent)
    defaultto :installed
  end

  newparam(:identifier, :namevar => true) do
    desc "The main PayloadIdentifier in the mobileconfig profile (usually at end of plist)"
  end

  newparam(:path) do
    desc "The path to the profile file on your system"
    validate do |value|
      unless value and Puppet::Util.absolute_path?(value)
        raise ArgumentError, "Profile path must be fully qualified, not '#{value}'"
      end
    end
  end

  newparam(:system, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    desc "Is this a device (system wide) profile?"
    defaultto false
    validate do |value|
      if value and self[:user]
        raise ArgumentError, "Scope error: must not set both user and system"
      else
        super
      end
    end
  end

  newparam(:user) do
    desc "The user to manage this profile for. system must be false if you set this."
    validate do |value|
      if !value and !self[:system]
        raise ArgumentError, "No scope defined: must set user or system"
      else
        super
      end
    end
  end

  newparam(:home) do
    desc "The users home dir, if it can't be guessed."
    defaultto do
      self[:user] ? File.join('', 'Users', self[:user]) : nil
    end
    validate do |value|
      unless !value or Puppet::Util.absolute_path?(value)
        raise ArgumentError, "Home path must be fully qualified, not '#{value}'"
      end
    end
  end

  autorequire(:file) do
    autos = []
    autos << self[:path]
    autos << self[:home] if self[:user]
    autos
  end

  autorequire(:user) do
    self[:user] ? self[:user] : nil
  end

  # This is a personal one - from our user module
  # It should not effect anyone else...
  autorequire(:exec) do
    self[:user] ? "managed_#{self[:user]}_home" : nil
  end

  # Respond to notify/subscribe events.
  # (usually after the file changes)
  def refresh
    # Only restart if present/installed
    if (@parameters[:ensure] || newattr(:ensure)).retrieve == :present
      provider.refresh
    else
      debug "Skipping refresh; profile is not present"
    end
  end

end
