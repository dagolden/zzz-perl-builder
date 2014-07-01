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

my $patchperl = Cwd::abs_path( File::Spec->catfile( dirname($0), 'patchperl.pl' ) );
my $yaml_file = Cwd::abs_path( File::Spec->catfile( dirname($0), 'perls.yml' ) );

my $build_dir     = Cwd::getcwd;
my $data          = Parse::CPAN::Meta->load_file($yaml_file);
my @common_config = split " ", $data->{common_config};

for my $perl ( @{ $data->{perls} } ) {
    say "Building $perl->{name}";
    my $prefix = File::Spec->catfile( $lang_path, $perl->{name} );
    unless ( -x File::Spec->catfile( $prefix, qw/bin perl/ ) ) {
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

    # switch to new perl for post install
    $ENV{PATH}                      = "$prefix/bin:$ENV{PATH}";
    $ENV{PERL_EXTUTILS_AUTOINSTALL} = "--defaultdeps";
    delete $ENV{$_} for qw/PERL5LIB PERL_MM_OPT PERL_MB_OPT/;

    try_run( 'cpan',  'App::cpanminus' );
    try_run( 'cpanm', 'TAP::Harness::Restricted' );

    # let's avoid any pod tests and prompts when we try to install stuff
    $ENV{HARNESS_SUBCLASS} = "TAP::Harness::Restricted";
    try_run( 'cpanm', @{ $data->{post_install} } ) if $data->{post_install};
}

sub try_run {
    my (@cmd) = @_;
    say "@cmd";
    if ( system(@cmd) ) {
        die "Failed: @cmd\n";
    }
}
