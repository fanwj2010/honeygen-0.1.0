#!/usr/bin/perl -w
package common;
use strict;
use warnings;
use XML::Tidy;
use XML::LibXML;
use Config::Scoped;
require Exporter;
our(@EXPORT, @ISA, @EXPORT_OK);
@ISA=qw(Exporter);
@EXPORT=qw(get_conf_hash indent_xml $dir_scenarios $dir_conf);
@EXPORT_OK=qw();

our $dir_conf = "/usr/share/honeygen/HoneyGen.conf";
our $cfg_hash = get_conf_hash($dir_conf);
our $install_directory = $cfg_hash->{config}->{install_directory};
our $dir_scenarios = $install_directory."scenarios/";

sub get_conf_hash{
   my $conf = $_[0];
   my $cs = Config::Scoped->new( file => $conf );
   my $cfg_hash = $cs->parse;
   return $cfg_hash;	
}

sub indent_xml{
  # create new   XML::Tidy object from MainFile.xml
  my $xml_file = $_[0];
  my $tidy_obj = XML::Tidy->new('filename' => $xml_file);
  # Tidy up the indenting
     $tidy_obj->tidy();
  # Write out changes back to MainFile.xml
     $tidy_obj->write();
}

1;
