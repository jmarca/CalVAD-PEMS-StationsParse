# Station metadata parsing

PeMS makes available the metadata for all detector stations.  They
recently changed the naming of those files to
`dXX_text_meta_YEAR_MONTH_DAY.txt`, but the internal format seems to
be the same as earlier (tab delimited files).

This program reads in those files and creates or updates the metadata
stored in the database.  Because we're considering historical data
always, this program generates versioned metadata for the detectors.
That is, the changes are tagged with the date recorded in the
metadata's filename, and the information is considered valid until it
is changed by another, subsequent metadata file with a later date.


# Installation

To install, use Dist::Zilla.

## prereqs

First install Dist::Zilla using cpan or cpanm

```
cpanm --sudo Dist::Zilla
```

Next install the Dist::Zilla plugins needed.

```
dzil authordeps --missing | cpanm --sudo
```

Next install the package dependencies, which are probably the
Spreadsheet parsing modules.

```
dzil listdeps --missing | cpanm --sudo
```

## Testing

Configuration of the tests is done using the file `test.config.json.
This file controls options to access databases.  An example is:

```javascript
{
    "couchdb": {
        "host": "127.0.0.1",
        "port":5984,
        "breakup_pems_raw_db": "test_calvad_pems_brokenup",
        "auth":{"username":"james",
                "password":"this is my couchdb passwrod"
               }
    },
    "postgresql":{
        "host":"192.168.0.1",
        "port":5432,
        "username":"james",
        "password":"my secret stapler horse",
        "breakup_pems_raw_db":"test_spatialvds"
    }
}
```

To run the tests, you can also use dzil

```
dzil test
```

If the tests don't pass, read the failing messages, and maybe try to
run each test individually using prove, like so:

```
prove -l t/02_exercise.t
```

As of this writing, the test simply reads in a single metadata file
from district 5.  This was chosen because the new, longer VDS detector
ids broke the old database definition (the integer values require
bigint, not int).

If I run into any other issues as time passes, the bug fixes will
likely require adding additional metadata files.

The point is that the tests can take some time to run, as they parse
each file completely and hit the database to write out all the
information.



## Install

Once the prerequisites are installed and the tests pass, you can
install.  This will again run the tests.

Two ways to do this.  First is to use sudo -E

```
sudo -E dzil install
```

The second is to use cpanm as the install command.

```
dzil install --install-command "cpanm --sudo ."
```

I prefer the second way.  You have to be sudo to install the module
in the global perl library, but there is no need to be sudo to run the
tests.  This second way uses the "sudo" flag for cpanm only when
installing, not for testing.

# Running the script to breakup and transpose the data

To actually run the program, do

```
perl -w parse_pems_stationstxt.pl
```

If you just run this, it will dump out a hopefully helpful
documentation of the command line options.

You can configure either with command line switches, or with a file
named `config.json`, or both.

The `config.json` can be like the test config file, except you can
also set command line switches too, like the year and the district.

Don't forget to set the config.json files to be mode 0600.  Not sure
what that means in windows, so you should probably run this on mac or
Linux.  Don't worry if you don't set that mode...the program will
crash and remind you in a Pavlovian punishment scheme.
