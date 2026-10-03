#!/usr/bin/perl

###
### This tool builds all binary dependencies required for FastNetMon
###


use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin/perllib";

use Fastnetmon;
use Getopt::Long;

#
# CentOS
# sudo yum install perl perl-Archive-Tar
#

my $library_install_folder = '/opt/fastnetmon-community/libraries';

my $os_type = '';  
my $distro_type = '';  
my $distro_version = '';  
my $distro_architecture = '';  
my $appliance_name = ''; 

my $temp_folder_for_building_project = `mktemp -d /tmp/fastnetmon.build.dir.XXXXXXXXXX`;
chomp $temp_folder_for_building_project;

unless ($temp_folder_for_building_project && -e $temp_folder_for_building_project) {
    die "Can't create temp folder in /tmp for building project: $temp_folder_for_building_project\n";
}

# Pass log path to module
$Fastnetmon::install_log_path = "/tmp/fastnetmon_install_$$.log";

# We do not need default very safe permissions
exec_command("chmod 755 $temp_folder_for_building_project");

my $start_time = time();

my $fastnetmon_code_dir = "$temp_folder_for_building_project/fastnetmon/src";

unless (-e $library_install_folder) {
    exec_command("mkdir -p $library_install_folder");
}

main();

### Functions start here
sub main {
    my $machine_information = Fastnetmon::detect_distribution();

    unless ($machine_information) {
        die "Could not collect machine information\n";
    }

    $distro_version = $machine_information->{distro_version};
    $distro_type = $machine_information->{distro_type};
    $os_type = $machine_information->{os_type};
    $distro_architecture = $machine_information->{distro_architecture};
    $appliance_name = $machine_information->{appliance_name};
	
    $Fastnetmon::library_install_folder = $library_install_folder;
    $Fastnetmon::temp_folder_for_building_project = $temp_folder_for_building_project;

    # Install build dependencies
    my $dependencies_install_start_time = time();
    install_build_dependencies();

    print "Installed dependencies in ", time() - $dependencies_install_start_time, " seconds\n";

    # Init environment
    init_compiler();

    # We do not use prefix "lib" in names as all of them are libs and it's meaning less
    # We use target folder names in this list for clarity
    # Versions may be in different formats and we do not use them yet
    my @required_packages = (
        'pcap_1_10_4',
        # 'gcc', # we build it separately as it requires excessive amount of time
        'openssl_1_1_1q',
        'cmake_3_23_4',
        
        'boost_build_4_9_2',
        'icu_65_1',
        'boost_1_81_0',

        'capnproto_0_8_0',
        'hiredis_0_14',
        'mongo_c_driver_1_23_0',
        
        # gRPC dependencies 
        're2_2022_12_01',
        'abseil_2024_01_16',        
        'zlib_1_3_1',
        'cares_1_18_1',

        'protobuf_21_12',
        'grpc_1_49_2',
        
        'elfutils_0_186',
        'bpf_1_0_1',
       
        'rdkafka_1_7_0',
        'cppkafka_0_3_1',

        'clickhouse_2_3_0',

        'gobgp_3_12_0',
        'log4cpp_1_1_4',
        'gtest_1_13_0'
    );

    # Accept package name from command line argument
    if (scalar @ARGV > 0) {
        @required_packages = @ARGV;
    }

    # To guarantee that binary dependencies are not altered in storage side we store their hashes in repository
    my $binary_build_hashes = { 
        'gcc_12_1_0' => {
            'ubuntu:24.04' => '535dcf6ab3e52355eff672f18d71580862ef842350aa422c73a65f2fbeddc3bdb5225e88622eab2b3e075647a25cfcc90e27bf89d36d536e973ec20034713740',
            'ubuntu:aarch64:24.04' => '',
            'debian:10'           => '',

            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => 'efdba95a611d38a0ed674c152a14dd561db51e824286f39bd324d2a508d8b45791f7a56488e0f30200a24f01cbe708055d3f32538dbbc09f4b17a51487579e41',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '6c199cef830187207bd3c34682fc635e5fa225d14aff4a1901196ea9255b9648ef0427fcbe6226e2ea0642d2793dc77be8b2d7f810e235a7a80e41a2f2705498',
            'ubuntu:aarch64:22.04'=> '',

            'centos:7'            => '',

            'centos:8'            => '78986413e65819b02bc65d7d4eaba58420bf812e8873290280c309643bca9925f01324be2894c9dc33cbcfbbdf270ec28d60d7e00b0356c6d08d55af3f94e849',
            'centos:aarch64:8'    => '',

            'centos:9'            => '63548a825467661c11c36d99562f2823a36ef44ebf915692554bb48e01ef9fae6d38f046a1816e4b23bb70d4a4ee61f34717f978c2e14e76913d8903328e4daf',
            'centos:aarch64:9'    => '',
        },
        'openssl_1_1_1q'        => {
            'ubuntu:24.04' => 'd464a81e7fdcec43d26123d5e86eac87b691cf4da46ca09b14bcf67ef4b7fc275d3ed5d4a016e970c9e5cb83b29895a0e428988b03642d4cbb307f0dfaca4a00',

            'ubuntu:aarch64:24.04'=> '',
            'centos:7'            => '',

            'centos:8'            => '9c2d0e6f43be3630851840a511b0c2442bd355f35e49047085d63b99a3225de9af66be8305a9252ad97c31ac442184b2b42d93252e6dc684b20f48923dc06b4a',
            'centos:aarch64:8'    => '',

            'centos:9'            => 'f0328f000f6103af349d03940c102dede0e31c8a9ba6c14da45069467c85eb5622a7f9eeda757b79f0dd2d3a69529462e84ad3441808fb25539b1195e0606e5e',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '5a3d4eb4f5449f7f4616e9589749a4ce81fafcc9e738896e4a59185f88aba45e93fb48a49b95ce6deb4fa49fb5d0639c448330748ff3badcf5d0c7de30312e67',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => 'a4a84da061cd3e1645d1d799ba55f8725f61aa9bbeeefad1fcca7c369fbbd74a68d9af5d74bf4e80c2bf686a670b0e242fa67fed16226a0ae1ee2c2c449cbf71',
            'ubuntu:aarch64:22.04'=> '',
        }, 
        'cmake_3_23_4'          => {
            'ubuntu:24.04' => '50205c99d7b7ecf5a5cadc078ea0b6d6903a9ebfa7d7468ca9361e73ea7589fdd4a16f8ba09ca00dbb4a07e132f581288dcceb5069cd741f4935fe0e1da30ef5',

            'ubuntu:aarch64:24.04' => '',
            'centos:7'            => '',

            'centos:8'            => '74aae21b4da6e997f4baec57fab25a237b7de959015bd0d9869d55a6a80a3c427f2ed701727e10e3ef08d8c02b2181968aa586005f08df03b04a80c2351514d2',
            'centos:aarch64:8'    => '',

            'centos:9'            => '7b8a768d3aa73a44e999e219b3c9fc549d64df9c4a670ca3507f2804f5d6019cf6100f705c6f5bb55e59714878e1928395d28681f8aa36f2ffbef92fed27b327',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '5e4d2a87c761db9dc3d74969225aec0116ea15b5776cd36b606c57f73e4647685007a447b60f1bc7857233e44bb38940cbe5bc036b6b26c89b3da11bef015bb2',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '1be59fcc7b3d89eb9fcd60b3af47963dc96b96d2d67ad849bfc1ae1efb293e974bde25ca60b6aebdd35f6fdf1b88674641696c5d71e86c6eaca31e3d26042969',
            'ubuntu:aarch64:22.04'=> '',
        },
        'boost_build_4_9_2'     => {
            'ubuntu:24.04' => 'f5242ecf5671cfa9b8e290c9f5e87fd1017b22b58928e770a67fe7b57915776a1b2f1eadf6abc45c6241ad697ea1092896f505ebb3a5ae18ec9eedf836aaca69',

            'ubuntu:aarch64:24.04' => '',
            'centos:7'            => '',

            'centos:8'            => 'e847b94d7fdf9cce25c64e03151cf44ff950c5dfb332bc7709de9677a4f25a6b97cc871b709d29de0315069183facb358ec132327cbb5eb746a4f6aea4bb06a8',
            'centos:aarch64:8'    => '',

            'centos:9'            => 'bb636d6f5e27ba347ec207462dd0527f4ce888a9b00d863e43a18e115a05854739daefcb31129ee3ace5c7bb7aab74515f1751c31033c4b40eabd2f3159afa44',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '', 
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '0f687d90e4322afdeff74754d32c14d437e7bdb143cf5678a8550c553794306b26572edf0abbd5df55d8072b242b08c9dcb453d1937579c62a59faf82668ecfa',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '1c71bd9b16928fbb92a293d64614930d88c556207ae5d9e2ee94b3e63a07c649fa43e4c7b909fd31adc3bcc1f5d74c09794490a4c4e89fb9f6c0b91a5a4690d6',
            'ubuntu:aarch64:22.04'=> '',
        },
        'icu_65_1'              => {
            'ubuntu:24.04' => 'e89700dbd08d5e7cfe6d438b20ca1010bf92f523905c06ed7b2a87d8d45521a39edcc6d86e1a555c011f75139287708f4b777e16190f3b0dbd9aa7967080d64c',

            'ubuntu:aarch64:24.04'=> '',
            'centos:7'            => '',

            'centos:8'            => 'f12959df4b0befc56a5faba3a9c6ef1b2d3990d141571e137d07b509cae73a09a635c6f17af008614120a09a4125d915f1b0ddb4ce9ca80542f6c4d125032faa',
            'centos:aarch64:8'    => '',

            'centos:9'            => 'ffd8fb3b45920782c462fc777e80d0ef075838deac6e2a344dd72c8aa4319ffeb3f706825502f872e5775c2ad681ad59494627de2c105fc621a9259ef6346741',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',
            'debian:11'           => '', 
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => 'd60d1c071eb6966533aa456b1b1ee5da2ea1286687a7e2cf7dada59b2d398dfe7cbceace030a8d4c57c0e621249f0ee7263c10c1fe52094204bcfa999cc2ffca',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => 'facf38965d6d889502cb0cb1d772448d8c28f0f729e73ce0553dc9c9798ed71fe801f9b01be37e9c41ecb6b917eb862a41fe44e6739dd51d89974b9e8e6a35dc',
            'ubuntu:aarch64:22.04'=> '',
        },
        'boost_1_81_0'          => {
            'ubuntu:24.04' => '',
            'ubuntu:aarch64:24.04' =>  '',
            'centos:7'            => '',

            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',
        },
        'capnproto_0_8_0'       => {
            'ubuntu:24.04' => '',
            'ubuntu:aarch64:24.04'=> '',
            'centos:7'            => '',

            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '', 
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',
        },
        'hiredis_0_14'          => {
            'ubuntu:24.04' => '',

            'ubuntu:aarch64:24.04'=>'',
            'centos:7'            => '',

            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '', 
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',
        },
        'mongo_c_driver_1_23_0' => {
            'ubuntu:24.04' => '',

            'ubuntu:aarch64:24.04'=> '',
            'centos:7'            => '',

            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',
            'debian:11'           => '', 
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',
        },
        're2_2022_12_01'        => {
            'ubuntu:24.04' => '',
            'ubuntu:aarch64:24.04'=> '',
            'centos:7'            => '',

            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '', 
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',
        },
        'abseil_2024_01_16'     => {
            'centos:7'            => '',

            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',

            'ubuntu:24.04'        => '',
            'ubuntu:aarch64:24.04'=> '',
        },
        'zlib_1_3_1' => {
            'centos:7'            => '',

            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',

            'ubuntu:24.04' => '',
            'ubuntu:aarch64:24.04'=> '',
        },
        'cares_1_18_1'          => {
            'centos:7'            => '',

            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '', 
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',
            'ubuntu:24.04' => '',
            'ubuntu:aarch64:24.04'=> '',
        },
        'protobuf_21_12'        => {
            'centos:7'            => '',

            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '', 
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',
            'ubuntu:24.04' => '',
            'ubuntu:aarch64:24.04'=> '',
        },
        'grpc_1_49_2'           => {
            'centos:7'            => '',

            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',
            'ubuntu:24.04' => '',
            'ubuntu:aarch64:24.04'=> '',
        },
        'elfutils_0_186'        => {
            'centos:7'            => '',

            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '', 
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',
            'ubuntu:24.04' => '',
            'ubuntu:aarch64:24.04'=> '',
        },
        'bpf_1_0_1'             => {
            'centos:7'            => '',

            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',
            'ubuntu:24.04' => '',
            'ubuntu:aarch64:24.04'=> '',
        },
        'rdkafka_1_7_0'           => {
            'centos:7'            => '',

            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '', 
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',
            'ubuntu:24.04' => '',
            'ubuntu:aarch64:24.04'=> '',
        },
        'clickhouse_2_3_0' => {
            'centos:7'             => '',
            'centos:8'             => '',
            'centos:aarch64:8'     => '',
            'centos:9'             => '',
            'centos:aarch64:9'     => '',
            'debian:10'            => '',
            'debian:11'            => '',
            'debian:aarch64:11'    => '',
            'debian:12'            => '',
            'debian:aarch64:12'    => '',
            'ubuntu:16.04'         => '',
            'ubuntu:18.04'         => '',
            'ubuntu:20.04'         => '',
            'ubuntu:aarch64:20.04' => '',
            'ubuntu:22.04'         => '',  
            'ubuntu:aarch64:22.04' => '',
            'ubuntu:24.04' => '',
            'ubuntu:aarch64:24.04'=> '',
        },
        'cppkafka_0_3_1'          => {
            'centos:7'            => '',

            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '', 
            'ubuntu:aarch64:22.04'=> '',
            'ubuntu:24.04' => '',
            'ubuntu:aarch64:24.04'=> '',
        },
        'gobgp_3_12_0'          => {
            'centos:7'            => '',

            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',
            'ubuntu:24.04' => '',
            'ubuntu:aarch64:24.04'=> '',
        },
        # It's actually 1_1_4rc3 but we use only minor and major numbers
        'log4cpp_1_1_4'         => {
            'centos:7'            => '',

            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',
            'ubuntu:24.04' => '',
            'ubuntu:aarch64:24.04'=> '',
        },
        'gtest_1_13_0' => {
            'debian:10'           => '',

            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',

            'centos:7'            => '',

            'centos:8'            => '',
            'centos:aarch64:8'    => '',

            'centos:9'            => '',
            'centos:aarch64:9'    => '',
            'ubuntu:24.04' => '',
            'ubuntu:aarch64:24.04'=> '',
        },
        'pcap_1_10_4' => {
            'ubuntu:24.04' => '0b0f8610a71f6faeb9f1bdf26325d00571d6a0234f4dbd69bfd28d8b16fc1358f42519054302a8c295a132f7bc88ffbe9adca792dcc0678a84cd2ddf5d340aaf',
            'ubuntu:aarch64:24.04'=> '',
            'centos:7'            => '',

            'centos:8'            => '24c8fa4f3e5e80d9391605c8e50b4abddf28932edd1f98d4363b43b911ce0c8109bad1944fc4e2474444c7f3dd994b2568ec415a29f1078cd79b404e0a5b7651',
            'centos:aarch64:8'    => '',

            'centos:9'            => '9786ce36678e53c92c5a6780933166a330184f145355f912f591bf9547cd036608b055f65502dd27a6579bad4f4f19e6d306164bda8b0aaa0a5c30e53c25ec89',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => 'b5348129fd1411f3e9510599ffa87d6da45b04e222367318701b729aba6c8f1e4eccbd324477d7347a4b227f695f968006423096dab9963debe1cf1c7b5a62ed',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '2843752dc12cbd3606f4ee2639387cbdd9b89c03896cd0efab657ff24b6d5d24aba3062fc19d65d9d7a6e34fd72048d7e213a76d8c1c827b5097f611c8f275d4',
            'ubuntu:aarch64:22.04'=> '',
        }
    };

    # How many seconds we needed to download all dependencies
    # We need it to investigate impact on whole build process duration
    my $dependencies_download_time = 0;

    for my $package (@required_packages) {
        print "Install package $package\n";
        my $package_install_start_time = time();

        # We need to get package name from our folder name
        # We use regular expression which matches first part of folder name before we observe any numeric digits after _ (XXX_12345)
        # Name may be multi word like: aaa_bbb_123
        my ($function_name) = $package =~ m/^(.*?)_\d/;

        # Check that package is not installed
        my $package_install_path = "$library_install_folder/$package";

        if (-e $package_install_path) {
            warn "$package is installed, skip build\n";
            next;
        }

        # This check just validates that entry for package exists in $binary_build_hashes
        # But it does not validate that anything in that entry is populated
        # When add new package you just need to add it as empty hash first
        # And then populate with hashes
        my $binary_hash = $binary_build_hashes->{$package}; 

        unless ($binary_hash) {
            die "Binary hash does not exist for $package, please create at least empty hash structure for it in binary_build_hashes\n";
        }

        my $cache_download_start_time = time();

        # Try to retrieve it from Cloudflare R2 bucket 
        my $get_from_cache = Fastnetmon::get_library_binary_build_from_r2($package, $binary_hash);

        my $cache_download_duration = time() - $cache_download_start_time;
        $dependencies_download_time += $cache_download_duration;

        if ($get_from_cache == 1) {
            print "Got $package from cache\n";
            next;
        }

        # In case of any issues with hashes we must break build procedure to raise attention
        if ($get_from_cache == 2) {
            die "Detected hash issues for package $package, stop build process, it may be sign of data tampering, manual checking is needed\n";
        }

        # We can reach this step only if file did not exist previously
        print "Cannot get package $package from cache, starting build procedure\n";

        # We provide full package name i.e. package_1_2_3 as second argument as we will use it as name for installation folder
        my $install_res = Fastnetmon::install_package_by_name($function_name, $package);
 
        unless ($install_res) {
            die "Cannot install package $package using handler $function_name: $install_res\n";
        }

        # We successfully built it, let's upload it to cache

        my $elapse = time() - $package_install_start_time;

        my $build_time_minutes = sprintf("%.2f", $elapse / 60);

        # Build only long time
        if ($build_time_minutes > 1) {
            print "Package build time: " . int($build_time_minutes) . " Minutes\n";
        }

        # Upload successfully built package to Cloudflare R2
        my $upload_binary_res = Fastnetmon::upload_binary_build_to_r2($package);

        # We can ignore upload failures as they're not critical
        if (!$upload_binary_res) {
            warn "Cannot upload dependency to cache\n";
            next;
        }


        print "\n\n";
    }

    my $install_time = time() - $start_time;
    my $pretty_install_time_in_minutes = sprintf("%.2f", $install_time / 60);

    print "We have installed all dependencies in $pretty_install_time_in_minutes minutes\n";
    
    my $cache_download_time_in_minutes = sprintf("%.2f", $dependencies_download_time / 60);
    
    print "We have downloaded all cached dependencies in $cache_download_time_in_minutes minutes\n";
}
