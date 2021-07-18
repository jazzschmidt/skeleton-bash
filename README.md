# SHKELETON - Bash Script Template

Shkeleton is a library that provides a convenient way to structure and
organize your bash scripts and assists you in writing versatile and easy-to-use programs.

## Features

Shkeleton makes it easy to 
- parse flag and argument options
- generate extensive usage information
- write scripts with different commands
- setup and cleanup the environment
- debug and trace your script

In addition to that, it offers functions to colorize output and emit error messages.  

## Minimal Example
Suppose this executable (chmod +x) `minimal-example.sh`:

```bash
#!/bin/bash

app_version="1.0.0"
app_description="Example Shkeleton Script"

source shkeleton.sh

function setup() {
    cmd "hello" "hello_world" "Displays 'hello world'"
}

function hello_world() {
    arg "n" "name" "string" "Greets <name> instead of 'world'"
    name=${arg:-world}

    if $flag_help; then
        printf "Displays the message 'hello world'.\n\n"
        print_usage && exit 0; # Print usage and exit
    fi
    
    debug "Debug log message"
    
    echo "hello ${name}" | green
}
```

**Executing the hello command**

![Executing the hello command](assets/example-1.gif)

**Showing the hello help**

![Showing the hello help](assets/example-2.png)

**Showing the script help**

![Showing the script help](assets/example-3.png)

## Parsing Options

Defining options is pretty easy in Shkeleton:
```bash
flag "s" "silent" "silences output"
local silent=$flag # true if either -s or --silent is present, false otherwise

flag "v" "increases verbosity"
local verbose=$flag # only true, when -v is set; short and long args are interchangeable

arg "n" "name" "string" "sets the name"
local name=${arg:-default} # the value of -n or --name or just 'default'

arg "max-age" "integer" "sets max-age"
local max_age=${arg:-} # the value of --max-age if present
````

The global variables `$flag` and `$arg` will hold the value directly after the
respective registering function has been called.

Options from the `setup` functions are treated as global flags and should therefore
be written to global variables (just like `$flag_help`), whereas options from
command functions should be saved as local variables like shown in the example above.

*Notice*: Options should be stated at the top of the command function,
so that `print_usage` shows them. 

## Commands and special Functions

The `cmd` command will add a named command, maps it to the given function and adds it
to the usage page. Commands should be defined in the `setup` function.
The `version` command is added per default.

There are a few special script workflow functions:

|Function|Description|
|---|---|
|`setup`|Bootstraps the script and adds commands and global flags|
|`teardown`|(Optional) Will be called when the script exits|
|`main`|(Optional) Will be called instead of usage page when script is being called without command |

Also, there are internal versions of these functions (`_setup`, `_teardown` and `_main`),
that can be extended when using Shkeleton as a library and common logic applies to all
your programs.

### Helper Functions

|Function|Description|
|---|---|
|`error`|Emits red error messages to stderr along with its root and exits|
|`debug`|Logs an orange/brown debug message|
|`colorize`|Colorizes output; can also be used as pipe|
|`red`, `green`, `blue`, ...|*see above*|
|`print_usage`|Prints usage information, should be called only after all options are set|
|`has_flag`|Sets `$flag` to `true` when the flag option exists, false otherwise|
|`get_arg`|Sets `$arg` to the argument options value if present|

## Debugging and Tracing

When called with `DEBUG` set to one of `1`, `true`, `yes` or `y`, debug messages
are shown and colorized. They are formatted like:

**`[DEBUG] <script-name> <command_function>: <message>`**

Since debugging of bash script can be pretty hard, you can also enable tracing by
supplying the `TRACE` parameter just like the debug parameter, which will enable
tracing as soon as the script enters your command.
