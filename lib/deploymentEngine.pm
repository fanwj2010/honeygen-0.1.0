#!/usr/bin/perl -w
package deploymentEngine;
use strict;
use warnings;
use common;

use XML::LibXML;
require Exporter;
our(@EXPORT, @ISA, @EXPORT_OK);
@ISA=qw(Exporter);
@EXPORT=qw(deployment_scenario reconfiguration_scenario);
@EXPORT_OK=qw();

sub deployment_scenario{
   my @params = @_;
   my $cfg_hash = get_conf_hash($dir_conf);
   my $platform = $cfg_hash->{config}->{platform};
   if($platform eq "vnx"){
        my $scenario_vnx_doc = $params[0];
        print "$scenario_vnx_doc\n";
        system("vnx -f $scenario_vnx_doc -v -t");
   }
   if($platform eq "honeyd"){
        my $scenario_honeyd_doc = $params[0];
        my $scenario_vnx_net = $params[1];
        my $net_name = $params[2]; 
        print "$scenario_vnx_net\n";
        system("vnx -f $scenario_vnx_net -v -t");
        print "$scenario_honeyd_doc\n";
        my $honeyd_exec_mode = $cfg_hash->{honeyd}->{mode}->{exec_mode};
        system("honeyd $honeyd_exec_mode -i $net_name -f $scenario_honeyd_doc");
       
   }
   if($platform eq "hybrid"){
       
   }
   if($platform eq "CIM"){
        
   }   
}
sub reconfiguration_scenario{
   my ($scenario_name,$scenario_vnx_reconf,$scenario_honeyd_reconf) = @_;
   my $cfg_hash = get_conf_hash($dir_conf);
   my $platform = $cfg_hash->{config}->{platform};
   if($platform eq "vnx"){
         system("vnx -s $scenario_name -m $scenario_vnx_reconf");   
   }
   if($platform eq "honeyd"){         
         #code to read the reconf line by line and exec one by one
   }
   if($platform eq "hybrid"){
        
   }
   if($platform eq "CIM"){
        
   }

}

1;
