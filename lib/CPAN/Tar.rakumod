unit class CPAN::Tar; # Please note this is just implement a part of USTAR standard !

use experimental :pack;
use nqp;

class THeader { ... }

once {
    for THeader.^attributes -> $attr {
        my $name = $attr.name.substr(2);
        THeader.^add_method("set-{$name}", method ($header: buf8 $v) {
            $header.set-buf($attr.get_value($header), $v);
            $header;
        });
    }
}

has $.out;

submethod TWEAK() {
    unless $!out.defined {
        die "Please provide something can write for CPAN::Tar!";
    }
}

method !prepare-header($path, $name) {
    my THeader $header .= new;
    $header.init();
    $header.set-size(
            buf8.new: pack(
            "A*",
                    sprintf "%011s", nqp::stat($path, nqp::const::STAT_FILESIZE).base(8)
            ));
    my ($prefix, $rname) = self!make-file-name($name);
    $header.set-name($rname);
    $header.set-prefix($prefix);
    $header.gen-checksum();
    $header;
}

method !make-file-name($name) {
    my $buf = buf8.new: pack("A*", $name);
    my $count = $buf.elems;

    $count = 155 if $count > 155;
    while $count > 0 && $buf[$count - 1] != 0x2f {
        $count--;
    }
    return ($buf.subbuf(0, $count - 1), $buf.subbuf($count));
}

method !end-record($size is copy) {
    my $count = 0;
    while $size % 512 != 0 {
        $count++;
        $size++;
    }
    if $count > 0 {
        $!out.write(buf8.new: 0 xx $count);
    }
}

method add(Str:D $path, Str:D $name) {
    my $header = self!prepare-header($path, $name);
    $header.out($!out);
    given $path.IO.open(:r) {
        while (my $buf = .read()) {
            $!out.write($buf);
        }
        .close();
    }
    self!end-record(nqp::stat($path, nqp::const::STAT_FILESIZE));
}

method pack() {
    my THeader $header .= new;
    $header.out($!out);
    $header.out($!out);
    $!out.close();
}

class THeader {
    has @.name;
    has @.mode;
    has @.uid;
    has @.gid;
    has @.size;
    has @.mtime;
    has @.checksum;
    has @.type;
    has @.linkname;
    has @.magic;
    has @.ver;
    has @.uname;
    has @.gname;
    has @.devmajor;
    has @.devminor;
    has @.prefix;
    has @.padding;

    submethod TWEAK() {
        @!name      := buf8.new(0 xx 100);
        @!mode      := buf8.new(0 xx 8);
        @!uid       := buf8.new(0 xx 8); # ignore
        @!gid       := buf8.new(0 xx 8); # ignore
        @!size      := buf8.new(0 xx 12);
        @!mtime     := buf8.new(0 xx 12);
        @!checksum  := buf8.new(0 xx 8);
        @!type      := buf8.new(0 xx 1);
        @!linkname  := buf8.new(0 xx 100);
        @!magic     := buf8.new(0 xx 6);
        @!ver       := buf8.new(0 xx 2);
        @!uname     := buf8.new(0 xx 32); # ignore
        @!gname     := buf8.new(0 xx 32);
        @!devmajor  := buf8.new(0 xx 8);
        @!devminor  := buf8.new(0 xx 8);
        @!prefix    := buf8.new(0 xx 155);
        @!padding   := buf8.new(0 xx 12);
    }

    method set-buf(@dest, $buf) {
        @dest.subbuf-rw(0, $buf.elems) = $buf;
    }

    method init() {
        self.set-buf(@!magic, buf8.new(pack("A*", "ustar")));
        self.set-buf(@!ver, buf8.new(pack("A*", "  ")));
        self.set-buf(@!mtime, buf8.new(pack("A*", sprintf "%011s", time.base(8))));
        self.set-buf(@!gname, buf8.new(pack("A*", "users")));
        self.set-buf(@!mode, buf8.new(pack("A*", sprintf "%07s", 0o644.base(8))));
    }

    sub __checksum($sum is rw, $buf) {
        for ^$buf.elems -> $i {
            $sum += $buf[$i] +& 0xff;
        }
    }

    method gen-checksum() {
        my Int $sum = 0;
        __checksum($sum, @!name);
        __checksum($sum, @!mode);
        __checksum($sum, @!uid);
        __checksum($sum, @!gid);
        __checksum($sum, @!size);
        __checksum($sum, @!mtime);
        $sum += ' '.ord for ^8;
        __checksum($sum, @!type);
        __checksum($sum, @!linkname);
        __checksum($sum, @!magic);
        __checksum($sum, @!ver);
        __checksum($sum, @!uname);
        __checksum($sum, @!gname);
        __checksum($sum, @!devmajor);
        __checksum($sum, @!devminor);
        __checksum($sum, @!prefix);
        __checksum($sum, @!padding);
        self.set-buf(@!checksum, buf8.new(pack("A*", sprintf "%06s", $sum.base(8))));
    }

    method out($out) {
        $out.write(@!name);
        $out.write(@!mode);
        $out.write(@!uid);
        $out.write(@!gid);
        $out.write(@!size);
        $out.write(@!mtime);
        $out.write(@!checksum);
        $out.write(@!type);
        $out.write(@!linkname);
        $out.write(@!magic);
        $out.write(@!ver);
        $out.write(@!uname);
        $out.write(@!gname);
        $out.write(@!devmajor);
        $out.write(@!devminor);
        $out.write(@!prefix);
        $out.write(@!padding);
    }
}
