
unit module CPAN::Pack6;

sub excluded-default($_) { $_ eq '.' || $_ eq '..' }

our proto copy-module-to(Str:D $src, Str:D $dest, |) {*}

        # copy file to directory
our multi sub copy-module-to(Str:D $src, Str:D $dest, &ex) {
    my (@stack, @dirs, @files);
    my ($ddir, $old) = ($dest.IO, $*CWD);

    # set the CWD to src directory, so we can get clean path of file/dir
    chdir($src);
    @stack.push: ".".IO;
    while +@stack > 0 {
        for @stack.pop.dir(test => { !&ex($_) && !&excluded-default($_) }) -> $f {
            @stack.push($f) if $f.d;
            $f.d ?? @dirs.push($f.Str) !! @files.push([ $f, $f.Str ]);
        }
    }
    chdir($old);
    # create directory tree first
    $ddir.add($_).mkdir for @dirs;
    # copy the file
    .[0].copy($ddir.add(.[1])) for @files;
}

        # copy file to directory
our multi sub copy-module-to(Str:D $src, Str:D $dest) {
    my (@stack, @dirs, @files);
    my ($ddir, $old) = ($dest.IO, $*CWD);

    # set the CWD to src directory, so we can get clean path of file/dir
    chdir($src);
    @stack.push: ".".IO;
    while +@stack > 0 {
        for @stack.pop.dir() -> $f {
            @stack.push($f) if $f.d;
            $f.d ?? @dirs.push($f.Str) !! @files.push([ $f, $f.Str ]);
        }
    }
    chdir($old);
    # create directory tree first
    $ddir.add($_).mkdir for @dirs;
    # copy the file
    .[0].copy($ddir.add(.[1])) for @files;
}
