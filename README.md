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

Note on an ARB machine during testing it was the case that using
`cpanm --sudo Dist::Zilla` resulted in hundreds of passwords being
requested for each install action.  If that happens bail out, and try
running `sudo cpanm Dist::Zilla`.



Next install the Dist::Zilla plugins needed.

```
dzil authordeps --missing | cpanm --sudo
```

Next install the package dependencies, which are probably the
Spreadsheet parsing modules.

```
dzil listdeps --missing | cpanm --sudo
```

## Moops, Kavorka, and Devel::CallParser

As of this writing (November 2017), `Devel::CallParser` has a bug that
causes Kavorka and Moops to fail installation.  The problem is known,
but the maintainer of Devel::CallParser is MIA.

The fix is as follows.

### Download Devel::CallParser

Get Devel::CallParser from
https://cpan.metacpan.org/authors/id/Z/ZE/ZEFRAM/Devel-CallParser-0.002.tar.gz

Download the most recent patch from this bug thread:
https://rt.cpan.org/Public/Bug/Display.html?id=110623

Alternately, just use the copy included in this repository.

Unzip the Devel-CallParser file

```
tar xvf Devel-CallParser-0.002.tar.gz
```

Change into the directory and apply the patch

```
cd Devel-CallParser-0.002
patch -p 1 < ../0002-Fix-a-pad-problem-with-Perl-5.24.1-on-unthreaded-build.patch
```

(Note that the patch command needs the patch.  I put it in the
directory above the Devel-CallParser code, but wherever it is, you
need to put in the correct path to the patch.)

The patch should apply cleanly.  If it doesn't check the bug thread
linked above.  Then make and install the code.

```
perl Build.PL
./Build
./Build test

... Result: PASS

sudo ./Build install
```

After that patched version of Devel-CallParser is installed, Moops
(and Kavorka) should install cleanly

```
cpanm --sudo Moops Kavorka
```

And with that, all of the dependencies required for this package
should be good to go (assuming you also manually installed the package
`spatialvds_schema` (from https://github.com/jmarca/spatialvds_schema)

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

Use cpanm as the install command.

```
dzil install --install-command "cpanm --sudo ."
```

This way uses the "sudo" flag for cpanm only when installing, not for
testing.

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
