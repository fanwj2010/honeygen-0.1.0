#!/usr/bin/perl -w
package honeyd_module;
use strict;
use warnings;
use common;
use autodie;
use vnx_module;
use XML::LibXML;
use IO::Socket::UNIX;
require Exporter;
our(@EXPORT, @ISA, @EXPORT_OK);
@ISA=qw(Exporter);
@EXPORT=qw(generate_honeyd_conf generate_vnx_net_for_honeyd honeyd_reconf_sock_client honeyd_del_template generate_honeyd_reconf);
@EXPORT_OK=qw();
my $SOCK_PATH =  "/var/run/honeyd.sock";
sub generate_honeyd_conf{
   my $scenario_doc = $_[0];
   my $parser = XML::LibXML->new();
   my $xml_scenario = $parser->parse_file($scenario_doc);
   my $root_scenario = $xml_scenario->getDocumentElement;
   my @nodes_scenario = $xml_scenario->findnodes('/honeynet/name');
   my $scenario_name = $nodes_scenario[$#nodes_scenario]->textContent;
   my $scenario_honeyd_doc = $dir_scenarios.$scenario_name."_honeyd.txt";
   open ( my $file_handle, ">>$scenario_honeyd_doc");

   @nodes_scenario = $xml_scenario->getDocumentElement->nonBlankChildNodes();
   foreach my $node_scenario (@nodes_scenario){
      my $node_name = $node_scenario->nodeName;
      if($node_name eq "router"){
          #my @gw_ips = $node_scenario->findnodes('gw');
          #my $gw_ip = $gw_ips[$#gw_ips]->textContent;
          my @nodes_if = $node_scenario->findnodes('if');
          my @nodes_route = $node_scenario->findnodes('route');
          foreach my $node_if(@nodes_if){
             my @if_ips = $node_if->findnodes('ipv4');
             my $if_ip_mask = $if_ips[$#if_ips]->textContent;
             my $net_prefix;
             my $if_net = $node_if->getAttribute('net');
             my @nets = $xml_scenario->findnodes("/honeynet/net");
             foreach my $net (@nets){
                  my @net_names = $net->findnodes('name');
                  my $net_name = $net_names[$#net_names]->textContent;
                  if($net_name eq $if_net){
                      my @net_prefixes =  $net->findnodes('network_ip_prefix');
                      $net_prefix = $net_prefixes[$#net_prefixes]->textContent; 
                  }
             }
             my ($if_ipv4, $mask) = split(/\//,$if_ip_mask);
             print $file_handle "route $if_ipv4 link $net_prefix \n";
             #print $file_handle "route $gw_ip add net $net_prefix $if_ipv4 \n";
             my @if_names = $node_if->findnodes('name');
             my $if_name = $if_names[$#if_names]->textContent;
             foreach my $node_route(@nodes_route){
                 my $dev_name = $node_route->getAttribute('dev');
                 if($dev_name eq $if_name){
                      my @route_dsts = $node_route->findnodes('dst');
                      my $route_dst = $route_dsts[$#route_dsts]->textContent;
                      my @route_gws = $node_route->findnodes('gw');
                      my $route_gw = $route_gws[$#route_gws]->textContent;
                      print $file_handle "route $if_ipv4 add net $route_dst $route_gw\n";
                 }
             }               
          }
         
          my @names_temp = $node_scenario->findnodes('name');
          my $name_temp = $names_temp[$#names_temp]->textContent;
          # Add the line to the file
          print $file_handle "create $name_temp \n";
          my @names_os = $node_scenario->findnodes('operating_system/name');
          my $name_os = $names_os[$#names_os]->textContent;
          my @versions_os = $node_scenario->findnodes('operating_system/version');
          my $version_os = $versions_os[$#versions_os]->textContent;
          my $personality = $name_os." ".$version_os;
          print $file_handle "set $name_temp personality \"$personality\" \n";
          
          my @nodes_service = $node_scenario->findnodes('service');
          my $cfg_hash = get_conf_hash($dir_conf);
          
          foreach my $node_service(@nodes_service){
             my @serv_names = $node_service->findnodes('name');
             my $serv_name = $serv_names[$#serv_names]->textContent;
             my @serv_ports = $node_service->findnodes('port');
             my $serv_port = $serv_ports[$#serv_ports]->textContent;
             my $servie_on_port = $cfg_hash->{honeyd}->{service}->{$serv_name};
             if($servie_on_port eq ""){
                  $serv_name = "default";
                  my $servie_on_port = $cfg_hash->{honeyd}->{service}->{$serv_name};
                  print $file_handle "add $name_temp tcp port $serv_port $servie_on_port $serv_port\n";
                  last;
             }
             print $file_handle "add $name_temp tcp port $serv_port \"$servie_on_port\"\n";
            
          }
          my $bool_mac = $node_scenario->exists('if/mac_addr');
          if($bool_mac == 1){
             my @nodes_mac = $node_scenario->findnodes('if/mac_addr');
             my $mac_addr = $nodes_mac[$#nodes_mac]->textContent;
             print $file_handle "set $name_temp ethernet \"$mac_addr\"\n";
          }
          foreach my $node_if(@nodes_if){
             my @if_ips = $node_if->findnodes('ipv4');
             my $if_ipv4 = $if_ips[$#if_ips]->textContent; 
             my @ipv4 = split(/\//,$if_ipv4);
             print $file_handle "bind $ipv4[0] $name_temp\n";
          }
          print $file_handle "\n";
      }
      if($node_name eq "honeypot"){
          my @names_temp = $node_scenario->findnodes('name');
          my $name_temp = $names_temp[$#names_temp]->textContent;
          # Add the line to the file
          print $file_handle "create $name_temp \n";
          my @names_os = $node_scenario->findnodes('operating_system/name');
          my $name_os = $names_os[$#names_os]->textContent;
          my @versions_os = $node_scenario->findnodes('operating_system/version');
          my $version_os = $versions_os[$#versions_os]->textContent;
          my $personality = $name_os." ".$version_os;
          print $file_handle "set $name_temp personality \"$personality\" \n";
          my @nodes_service = $node_scenario->findnodes('service');
          my $cfg_hash = get_conf_hash($dir_conf);
          

          foreach my $node_service(@nodes_service){
             my @serv_names = $node_service->findnodes('name');
             my $serv_name = $serv_names[$#serv_names]->textContent;
             my @serv_ports = $node_service->findnodes('port');
             my $serv_port = $serv_ports[$#serv_ports]->textContent;
             my $servie_on_port = $cfg_hash->{honeyd}->{service}->{$serv_name};
             if($servie_on_port eq ""){
                  $serv_name = "default";
                  my $servie_on_port = $cfg_hash->{honeyd}->{service}->{$serv_name};
                  print $file_handle "add $name_temp tcp port $serv_port $servie_on_port $serv_port\n";
                  last;
             } 
             print $file_handle "add $name_temp tcp port $serv_port \"$servie_on_port\"\n";
          }
          my $bool_mac = $node_scenario->exists('if/mac_addr');
          if($bool_mac == 1){
             my @nodes_mac = $node_scenario->findnodes('if/mac_addr');
             my $mac_addr = $nodes_mac[$#nodes_mac]->textContent;
             print $file_handle "set $name_temp ethernet \"$mac_addr\"\n";
          }
          my @nodes_if = $node_scenario->findnodes('if');
          foreach my $node_if(@nodes_if){
             my @if_ips = $node_if->findnodes('ipv4');
             my $if_ipv4 = $if_ips[$#if_ips]->textContent; 
             my @ipv4 = split(/\//,$if_ipv4);
             print $file_handle "bind $ipv4[0] $name_temp\n";
          }
          print $file_handle "\n";
      }
   
   }
   close $file_handle;
   return $scenario_honeyd_doc; 
}

sub generate_vnx_net_for_honeyd{
    my $scenario_doc = $_[0];
    my $parser = XML::LibXML->new();
    my $xml_scenario = $parser->parse_file($scenario_doc);
    my @nodes_scenario = $xml_scenario->findnodes('/honeynet/name');
    my $scenario_name = $nodes_scenario[$#nodes_scenario]->textContent;
    my $scenario_vnx_net = $dir_scenarios.$scenario_name."_vnx_net.xml";
    $scenario_vnx_net = create_vnx_init_doc($scenario_vnx_net, $scenario_name);
    my $xml_vnx = $parser->parse_file($scenario_vnx_net);
    my $root_vnx = $xml_vnx->getDocumentElement;
    my @nodes_vnx = $xml_vnx->findnodes('/vnx/globle');
    my $refNode = $nodes_vnx[$#nodes_vnx];
    @nodes_scenario = $xml_scenario->getDocumentElement->nonBlankChildNodes();
    foreach my $node_scenario (@nodes_scenario){
      my $node_name = $node_scenario->nodeName;
      if($node_name eq "net"){
          my $node_net = $xml_vnx->createElement("net");
          my @nodes = $node_scenario->findnodes('name');
          my $name = $nodes[$#nodes]->textContent;
          $node_net->setAttribute("name",$name);
          $node_net->setAttribute("mode","virtual_bridge");
          $root_vnx->insertAfter( $node_net, $refNode);
          $refNode =  $node_net;  
      }
=pod
      if($node_name eq "router"){
         my $node_vm = $xml_vnx->createElement("vm");
         my @nodes = $node_scenario->findnodes('name');
         my $name = $nodes[$#nodes]->textContent;
         $node_vm->setAttribute("name",$name);
         $node_vm->setAttribute("type","lxc");
         my $node_filesystem = XML::LibXML::Element->new("filesystem");
         $node_filesystem->setAttribute("type","cow");               
         $node_filesystem->appendText("/usr/share/vnx/filesystems/honeydrive_lxc");
         $node_vm->appendChild( $node_filesystem );    
         @nodes = $node_scenario->findnodes('if');
         foreach my $node(@nodes){
            my $node_if = $node->cloneNode(0);
            my @ipv4 = $node->findnodes('ipv4');
            my $node_ipv4 = $ipv4[$#ipv4]->cloneNode(1);
            $node_if->appendChild($node_ipv4);
            $node_vm->appendChild( $node_if);
         }        
         my $node_route = XML::LibXML::Element->new("route");  
         $node_route->setAttribute("type","ipv4");
         @nodes = $node_scenario->findnodes('gw');
         my $gw = $nodes[$#nodes]->textContent;               
         $node_route->setAttribute("gw",$gw);               
         $node_route->appendText("default");
         $node_vm->appendChild( $node_route);  
         $root_vnx->insertAfter( $node_vm, $refNode);
         $refNode =  $node_vm;
      }
=cut
   }
   @nodes_scenario = $xml_scenario->findnodes("/honeynet/net");
   my @net_names = $nodes_scenario[0]->findnodes('name'); 
   my $net_name = $net_names[0]->textContent;
   my @net_prefixes = $nodes_scenario[0]->findnodes('network_ip_prefix');
   my $net_prefix = $net_prefixes[0]->textContent;
   my ($netip, $mask) = split(/\//,$net_prefix);
   my @ip_split = split(/\./,$netip);
   my $ipv4 = $ip_split[0].'.'.$ip_split[1].'.'.$ip_split[2].'.1'."\/".$mask;      
   my $node_host = XML::LibXML::Element->new("host");
   my $hostif = XML::LibXML::Element->new("hostif");
   $hostif->setAttribute("net",$net_name);               
   my $node_ipv4 = XML::LibXML::Element->new("ipv4");   
   $node_ipv4->appendText($ipv4);
   $hostif->appendChild($node_ipv4);
   $node_host->appendChild($hostif);
   $root_vnx->insertAfter( $node_host, $refNode);
   $xml_vnx->toFile($scenario_vnx_net);
   indent_xml($scenario_vnx_net);
   return ($scenario_vnx_net, $net_name);
}
sub honeyd_del_template{
    my $del_template = $_[0];
    print "$del_template\n";
    my $exec_line = "delete ".$del_template."\n";
    print $exec_line;
    honeyd_reconf_sock_client($exec_line);
}

sub generate_honeyd_reconf{
   my ($scenario_name,$xml_req) = @_;
   my $scenario_honeyd_reconf;
   #code
   return $scenario_honeyd_reconf;
}

sub honeyd_reconf_sock_client{
    my $exec_line = $_[0];
    my $sock_client = IO::Socket::UNIX->new(
       Type => SOCK_STREAM(),
       Peer => $SOCK_PATH,
    );
    die "Can't create socket: $!" unless $sock_client;
    print $sock_client "$exec_line";
}



1;
