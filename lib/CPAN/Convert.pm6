
unit module CPAN::Convert;

use File::Which;

&*pack6-hook.wrap(&default-hook);

# $path is the directory that files are ready
# convert asciidoc to markdown, using asciidoctor and pandoc
sub default-hook(Str:D $path) {
    my @stack;

    # set the CWD to src directory, so we can get clean path of file/dir
    @stack.push: $path.IO;
    while +@stack > 0 {
        for @stack.pop.dir() -> $f {
            @stack.push($f) if $f.d;
            if $f.f && $f.extension eq "adoc" {
                &convert-asciidoc($f.Str, $f.subst(/"adoc"$/, "md"));
                $f.unlink;
            }
        }
    }
}

sub convert-asciidoc(Str:D $path, Str:D $out) {
    if check-dependence(< asciidoctor iconv pandoc >) {
        die "Can not find command: ", $_;
    }
    my @commands = [
        'asciidoctor' => [ "-b", "docbook", $path,       "-o", "{$path}.xml" ],
                'iconv'       => [ "-t", "utf8",    "$path.xml", "-o", "{$path}.xml2"],
                        -> { unlink("{$path}.xml"); },
                        'pandoc'      => [ "-f", "docbook", "-t", "gfm", "{$path}.xml2", "-o", $out],
                                -> { unlink("{$path}.xml2"); },
    ];
    for @commands -> $cmd {
        if $cmd ~~ Callable {
            &$cmd();
        } else {
            if simple-run($cmd.key, @($cmd.value())) != 0 {
                die "Run command failed: ", $cmd.gist;
            }
        }
    }
}

sub simple-run(Str $cmd, @args) {
    my $proc = do if $*DISTRO.is-win {
        run('cmd', '/c', $cmd, |@args);
    } else {
        run($cmd, |@args);
    };
    $proc;
}

sub check-dependence(@cmds --> Str) {
    for @cmds -> $cmd {
        if ! which($cmd).defined {
            return $cmd;
        }
    }
}

