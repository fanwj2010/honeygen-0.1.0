#!/usr/bin/perl -w
package vnx_module;
use strict;
use warnings;
use common;
use XML::LibXML;
use XML::Writer;
use IO::File;
use requestProcessor;
require Exporter;
our(@EXPORT, @ISA, @EXPORT_OK);
@ISA=qw(Exporter);
@EXPORT=qw(generate_vnx_conf create_vnx_init_doc generate_vnx_reconf);
@EXPORT_OK=qw();
sub create_vnx_net_content{
   my($node_scenario, $p_node_net)=@_;
   my @net_names = $node_scenario->findnodes('name');
   my $net_name = $net_names[$#net_names]->textContent;
   $$p_node_net->setAttribute("name",$net_name);
   $$p_node_net->setAttribute("mode","virtual_bridge");

}

sub create_vnx_vm_content{
   my($node_scenario, $p_node_vm)=@_;
   my $cfg_hash = get_conf_hash($dir_conf);
   my $install_dir = $cfg_hash->{config}->{install_directory};
   my $platform = $cfg_hash->{config}->{platform};
   my $interaction_level;
   my $deployment_tool;
   my $filesystem;
   my $os_name;
   my $os_version;
   my @vm_names = $node_scenario->findnodes('name');
   my $vm_name = $vm_names[$#vm_names]->textContent;
   $$p_node_vm->setAttribute("name",$vm_name);
   my $bool_interact = $node_scenario->exists('interaction_level');
   if($bool_interact == 0){
      $interaction_level = "default";
      $deployment_tool = $cfg_hash->{tool}->{interaction_level}->{$platform}->{$interaction_level};
   }
   else{
      my @interaction_levels = $node_scenario->findnodes("interaction_level");
      $interaction_level = $interaction_levels[$#interaction_levels]->textContent;
      if($interaction_level eq ""){
         $interaction_level = "default";
         $deployment_tool = $cfg_hash->{tool}->{interaction_level}->{$platform}->{$interaction_level};
      }
      if($interaction_level eq "low"){
         $deployment_tool = $cfg_hash->{tool}->{interaction_level}->{$platform}->{$interaction_level};
      }
      if($interaction_level eq "high"){
         $deployment_tool = $cfg_hash->{tool}->{interaction_level}->{$platform}->{$interaction_level};
      }
   }
   if($deployment_tool eq "lxc"){
      $$p_node_vm->setAttribute("type","lxc");
   }
   if($deployment_tool eq "kvm"){
      $$p_node_vm->setAttribute("type","libvirt");
      $$p_node_vm->setAttribute("subtype","kvm");
      $$p_node_vm->setAttribute("os","linux");
   }
   my $node_filesystem = XML::LibXML::Element->new("filesystem");
   $node_filesystem->setAttribute("type","cow");               
   my $bool_os = $node_scenario->exists('operating_system');
   if($bool_os ==0 ){
        my $filesystem_type = "default";
        my $filesystem_content = $cfg_hash->{lxc}->{$filesystem_type}; 
        $filesystem = $install_dir.$filesystem_content;                 
   }
   else{
        my @os_names = $node_scenario->findnodes("operating_system/name");
        $os_name = $os_names[$#os_names]->textContent;
        my @os_versions = $node_scenario->findnodes("operating_system/version");
        $os_version = $os_versions[$#os_versions]->textContent;
        my $filesystem_content = $cfg_hash->{$deployment_tool}->{$os_name}->{$os_version}->{filesystem}; 
        $filesystem = $install_dir.$filesystem_content;
   }        
   $node_filesystem->appendText($filesystem);
   $$p_node_vm->appendChild( $node_filesystem );
   my $node_mem = XML::LibXML::Element->new("mem");
   $node_mem->appendText("256M");
   $$p_node_vm->appendChild($node_mem);
   my @scenario_node_ifs = $node_scenario->findnodes('if');
   foreach my $scenario_node_if(@scenario_node_ifs){
        my $vnx_node_if = $scenario_node_if->cloneNode(0);
        my @scenario_node_if_ipv4s = $scenario_node_if->findnodes('ipv4');
        my $vnx_node_if_ipv4 = $scenario_node_if_ipv4s[$#scenario_node_if_ipv4s]->cloneNode(1);
        $vnx_node_if->appendChild($vnx_node_if_ipv4);
        $$p_node_vm->appendChild($vnx_node_if);
   }
   my @scenario_routes = $node_scenario->findnodes('route');
   foreach my $scenario_route(@scenario_routes){
        my @scenario_route_dsts = $scenario_route->findnodes('dst'); 
        my $scenario_route_dst = $scenario_route_dsts[$#scenario_route_dsts]->textContent;
        my @scenario_route_gws = $scenario_route->findnodes('gw'); 
        my $scenario_route_gw = $scenario_route_gws[$#scenario_route_gws]->textContent;
        my $node_route = XML::LibXML::Element->new("route");
        #now it only support ipv4
        $node_route->setAttribute("type","ipv4");
        $node_route->setAttribute("gw",$scenario_route_gw);
        $node_route->appendText($scenario_route_dst);
        $$p_node_vm->appendChild($node_route);
   }
   
   my $node_exec = XML::LibXML::Element->new("exec");
   $node_exec->setAttribute("seq","on_boot");               
   $node_exec->setAttribute("type","verbatim");               
   my $bool_service = $node_scenario->exists('service');
   if($bool_service == 0){
       #$node_exec->appendText("/opt/dionaea/dionaea/src/dionaea -r /opt/dionaea");          
       #$$p_node_vm->appendChild($node_exec);
   }
   else{
       my @node_services = $node_scenario->findnodes('service');
       foreach my $node_service (@node_services){
          my @node_service_names = $node_service->findnodes('name');
          my $node_service_name = $node_service_names[$#node_service_names]->textContent; 
          my $service_content = $cfg_hash->{$deployment_tool}->{$os_name}->{$os_version}->{service}->{$node_service_name}; 
          $node_exec->appendText($service_content);
          $$p_node_vm->appendChild($node_exec);
       }
   }

          
}

sub generate_vnx_conf{
   my ($scenario_doc) = @_;
   my $parser = XML::LibXML->new();
   my $xml_scenario = $parser->parse_file($scenario_doc);
   my $root_scenario = $xml_scenario->getDocumentElement;

   my @nodes_scenario = $xml_scenario->findnodes('/honeynet/name');
   my $scenario_name = $nodes_scenario[$#nodes_scenario]->textContent;
   my $scenario_vnx_doc = $dir_scenarios.$scenario_name."_vnx.xml";
   
   $scenario_vnx_doc = create_vnx_init_doc($scenario_vnx_doc, $scenario_name);
   
   my $xml_vnx = $parser->parse_file($scenario_vnx_doc);
   my $root_vnx = $xml_vnx->getDocumentElement;
   my @nodes_vnx = $xml_vnx->findnodes('/vnx/globle');
   my $refNode = $nodes_vnx[$#nodes_vnx];
   @nodes_scenario = $xml_scenario->getDocumentElement->nonBlankChildNodes();
   foreach my $node_scenario (@nodes_scenario){
      my $node_name = $node_scenario->nodeName;
      if($node_name eq "net"){
          my $node_net = $xml_vnx->createElement("net");
          create_vnx_net_content($node_scenario, \$node_net);
          $root_vnx->insertAfter($node_net, $refNode);
          $refNode =  $node_net;  
      }
      if($node_name eq "honeypot"){
          my $node_vm = $xml_vnx->createElement("vm");
          create_vnx_vm_content($node_scenario, \$node_vm);     
          $root_vnx->insertAfter( $node_vm, $refNode);
          $refNode =  $node_vm;  
      }
      if($node_name eq "router"){
          my $node_vm = $xml_vnx->createElement("vm");
          create_vnx_vm_content($node_scenario, \$node_vm); 
          my $node_forwarding = XML::LibXML::Element->new("forwarding");
          $node_forwarding->setAttribute("type","ip");
          $node_vm->appendChild($node_forwarding);
          $root_vnx->insertAfter( $node_vm, $refNode);
          $refNode =  $node_vm;  
      }
      
   }
   $xml_vnx->toFile($scenario_vnx_doc);
   indent_xml($scenario_vnx_doc);
   return $scenario_vnx_doc;
}

sub generate_vnx_reconf{
   my ($scenario_name,$p_xml_req) = @_;
   my $parser = XML::LibXML->new();
   my $scenario_vnx_reconf = $dir_scenarios.$scenario_name."_vnx_reconf.xml";
   $scenario_vnx_reconf = create_vnx_reconf_doc($scenario_vnx_reconf);
   my $xml_vnx_reconf = $parser->parse_file($scenario_vnx_reconf);
   my $root_vnx_reconf = $xml_vnx_reconf->getDocumentElement;
   my @nodes_req = $$p_xml_req->getDocumentElement->nonBlankChildNodes();
   foreach my $node_req(@nodes_req){
      my $node_name = $node_req->nodeName;
      
      if($node_name eq "net"){
          my $node_net = $node_req;
          my @node_net_names = $node_net->findnodes("name");
          my $node_net_name = $node_net_names[$#node_net_names]->textContent; 
          
          my $net_status ="";
          my $bool_a = $node_net->hasAttribute('status');
          if($bool_a == 1){
             $net_status = $node_net->getAttribute('status');
          }
          my $net_request =""; 
          $bool_a = $node_net->hasAttribute('request');
          if($bool_a == 1){
             $net_request = $node_net->getAttribute('request');
          }
 
          if($net_status eq "up"){
              my $node_up_net = $xml_vnx_reconf->createElement("up_net");
              $node_up_net->setAttribute("name",$node_net_name);
              $root_vnx_reconf->appendChild($node_up_net);  
          }
          if($net_status eq "down"){
              my $node_down_net = $xml_vnx_reconf->createElement("down_net");
              $node_down_net->setAttribute("name",$node_net_name);
              $root_vnx_reconf->appendChild($node_down_net);  
          }
          if($net_request eq "add"){
              my $node_add_net = $xml_vnx_reconf->createElement("add_net");
              $node_add_net->setAttribute("name",$node_net_name);
              $node_add_net->setAttribute("mode","virtual_bridge");
              $root_vnx_reconf->appendChild($node_add_net);  
          }
          if($net_request eq "del"){
              my $node_del_net = $xml_vnx_reconf->createElement("del_net");
              $node_del_net->setAttribute("name",$node_net_name);
              $node_del_net->setAttribute("del","no");
              $root_vnx_reconf->appendChild($node_del_net);  
          }
      }
      if($node_name eq "honeypot"){
          my $node_honeypot = $node_req;
          my @node_honeypot_names = $node_honeypot->findnodes("name");
          my $node_honeypot_name = $node_honeypot_names[$#node_honeypot_names]->textContent;
          
          my $honeypot_status ="";
          my $bool_a = $node_honeypot->hasAttribute('status');
          if($bool_a == 1){
             $honeypot_status = $node_honeypot->getAttribute('status');
          }
          my $honeypot_request =""; 
          $bool_a = $node_honeypot->hasAttribute('request');
          if($bool_a == 1){
             $honeypot_request = $node_honeypot->getAttribute('request');
          }

          print "request--------[$node_honeypot_name]-------------[$honeypot_request]\n"; 
          if($honeypot_status eq "shutdown"){
              my $node_down_honeypot = $xml_vnx_reconf->createElement("del_vm");
              $node_down_honeypot->setAttribute("name",$node_honeypot_name);
              $node_down_honeypot->setAttribute("mode","shutdown");
              $root_vnx_reconf->appendChild($node_down_honeypot);  
          }
          if($honeypot_request eq "add"){
              print "add--------[$node_honeypot_name]\n"; 
              my $node_add_honeypot = $xml_vnx_reconf->createElement("add_vm");
              create_vnx_vm_content($node_honeypot, \$node_add_honeypot); 
              $root_vnx_reconf->appendChild($node_add_honeypot);  
          }
          if($honeypot_request eq "del"){
              my $node_del_honeypot = $xml_vnx_reconf->createElement("del_vm");
              $node_del_honeypot->setAttribute("name",$node_honeypot_name);
              $node_del_honeypot->setAttribute("mode","destroy");
              $root_vnx_reconf->appendChild($node_del_honeypot); 
          }
          if($honeypot_request eq "set"){
          }       
      }
      if($node_name eq "router"){
          my $node_router = $node_req;
          my @node_router_names = $node_router->findnodes("name");
          my $node_router_name = $node_router_names[$#node_router_names]->textContent;

          my $honeypot_request = "";
          my $bool_a = $node_req->hasAttribute('request');
          if($bool_a == 1){
             $honeypot_request = $node_req->getAttribute('request');
          }
          if($honeypot_request eq "add"){
               my $node_vm = $xml_vnx_reconf->createElement("add_vm");
          }
          if($honeypot_request eq "del"){
          }
          if($honeypot_request eq "set"){
          }       
      }
   }
   $xml_vnx_reconf->toFile($scenario_vnx_reconf);
   indent_xml($scenario_vnx_reconf);
   
   return $scenario_vnx_reconf;
}

sub create_vnx_reconf_doc{
   my ($vnx_reconf_doc) = @_;
   my $output = IO::File->new(">$vnx_reconf_doc");
   my $doc = XML::Writer->new(OUTPUT => $output);
   $doc->xmlDecl("UTF-8");
   $doc->startTag("modify_vnx");
   $doc->endTag(); # close doc
   $doc->end(); # final checks
   $output->close();
   indent_xml($vnx_reconf_doc);
   return $vnx_reconf_doc;
}

sub create_vnx_init_doc{
   my ($scenario_vnx_doc,$scenario_name) = @_;
   print "go--------------------$scenario_vnx_doc\n";
   my $output = IO::File->new(">$scenario_vnx_doc");
   my $doc = XML::Writer->new(OUTPUT => $output);
   $doc->xmlDecl("UTF-8");
   $doc->startTag("vnx", "xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance",
  "xsi:noNamespaceSchemaLocation"=>"/usr/share/xml/vnx/vnx-2.00.xsd");
       $doc->startTag("global");
           $doc->dataElement ("version" => "2.0");
           $doc->dataElement ("scenario_name" => "$scenario_name");
           $doc->dataElement ("automac");
           $doc->dataElement("vm_mgmt" =>"", "type"=>"none");
=pod
           $doc->startTag("vm_mgmt", "type"=>"private", "network"=>"10.250.0.0", "mask"=>"24", "offset"=>"12");
               $doc->dataElement ("host_mapping");
           $doc->endTag("vm_mgmt");
=cut
           $doc->startTag("vm_defaults");
                $doc->dataElement ("console"=>"", "id"=>"0", "display"=>"yes");
                $doc->dataElement ("console"=>"", "id"=>"1", "display"=>"yes");
           $doc->endTag("vm_defaults");
       $doc->endTag("global");
   $doc->endTag(); # close doc
   $doc->end(); # final checks
   $output->close();
   indent_xml($scenario_vnx_doc);
   return $scenario_vnx_doc;   
}

1;
