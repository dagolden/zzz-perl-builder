#!/usr/bin/env perl
use v5.10.1;
use strict;
use warnings;
use autodie;

use Parse::CPAN::Meta;
use File::Spec;
use File::Basename qw/dirname/;
use File::Path qw/remove_tree/;
use Cwd;

my $lang_path = shift or die "Usage: $0 <path-to-install-perls>\n";

my $patchperl = File::Spec->catfile( dirname($0), 'patchperl.pl' );
my $yaml_file = File::Spec->catfile( dirname($0), 'perls.yml' );

my $build_dir     = Cwd::getcwd;
my $data          = Parse::CPAN::Meta->load_file($yaml_file);
my @common_config = split " ", $data->{common_config};

for my $perl ( @{ $data->{perls} } ) {
    say "Building $perl->{name}";
    my $prefix = File::Spec->catfile( $lang_path, $perl->{name} );
    next if -x File::Spec->catfile( $prefix, qw/bin perl/ );

    chdir $build_dir;
    my @local_config = $perl->{config} ? ( split " ", $perl->{config} ) : ();
    my @config = ( @common_config, "-Dprefix=$prefix", @local_config );
    my ($tarball) = $perl->{url} =~ m{.*/(.*)};
    ( my $src_dir = $tarball ) =~ s{\.tar\.gz}{};

    try_run( "wget", $perl->{url} ) unless -f $tarball;
    remove_tree($src_dir) if -d $src_dir;
    try_run( "tar", "-xzf", $tarball );

    chdir $src_dir;

    try_run( $^X,           $patchperl );
    try_run( "./Configure", @config );
    try_run( "make",        "-j9" );
    try_run( "make",        "install" );
}

sub try_run {
    my (@cmd) = @_;
    say "@cmd";
    if ( system(@cmd) ) {
        die "Failed: @cmd\n";
    }
}
