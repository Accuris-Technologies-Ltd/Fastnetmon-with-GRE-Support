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
            'ubuntu:aarch64:24.04' => 'ff69223cdc520f1d5358e2c33350b531a7c7363ca84fdbdaea9da79c61472a315a4bcc60db178592322755fd7e74c7eb59a1a03769793b5f97dc81705333b8bb',
            'debian:10'           => '',

            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '72869b9cda377c94369c5a5cc3f0fa6a3f633e84fb344c7e209e8bf99fa941377c0903d0684eaab39b36310335df13882b2bd187f28bb5d3d7846f205454a597',
            'debian:aarch64:12' => '010e59561cf1ccd395d42c36e3cfa2d9d0fe8a91ad5a37d05563ee6ca83313bdc51c0733e6f27dad538f549d56bc00ea71aed3933e9e424015f3f4200565fe48',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => 'efdba95a611d38a0ed674c152a14dd561db51e824286f39bd324d2a508d8b45791f7a56488e0f30200a24f01cbe708055d3f32538dbbc09f4b17a51487579e41',
            'ubuntu:aarch64:20.04'=> 'd91cfa2ab254e8e655852ecc10d83467a4d1c8cd20193999d7c66ac168bef89455664fb14ef19cd5efe4173fb8fa30c29822177f47ceb19f5446ac0f393c7d93',

            'ubuntu:22.04'        => '6c199cef830187207bd3c34682fc635e5fa225d14aff4a1901196ea9255b9648ef0427fcbe6226e2ea0642d2793dc77be8b2d7f810e235a7a80e41a2f2705498',
            'ubuntu:aarch64:22.04'=> '6362484647edd04dfe005e65629c7eebefb161e8344efd169bbdc6ff45b478ede83c0d664ec86943dd9dd4dd2089a1744f7efdd462bbb4cd0fc0dda3ba325872',

            'centos:7'            => '',

            'centos:8'            => '78986413e65819b02bc65d7d4eaba58420bf812e8873290280c309643bca9925f01324be2894c9dc33cbcfbbdf270ec28d60d7e00b0356c6d08d55af3f94e849',
            'centos:aarch64:8'    => '272a4fda75fab7cd6354f9ea06c9d31db67d5fc1ea051fb23d0b91e3462d2f92c3a551453b8d1d07d6103874e67334ccbbc4e68d2d38a41c46e2bcb72537f6b8',

            'centos:9'            => '63548a825467661c11c36d99562f2823a36ef44ebf915692554bb48e01ef9fae6d38f046a1816e4b23bb70d4a4ee61f34717f978c2e14e76913d8903328e4daf',
            'centos:aarch64:9'    => '38d85c766259d58530521eab5d40b009e7490e485d0f94abd2c25b6fb328bbaf1e1a9409487f59b7f295793abf7e457229e3414caef95fe613adcaa742346b45',
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
            'ubuntu:24.04' => '3b624a8827e802bd8e188ca8f580ddea17ae824cd974f8d031cd680c86cf983efbd801d20ef7da68ed40b946d6c0108dba0d3d52fd73a50294f0beeef1c177f3',
            'ubuntu:aarch64:24.04' =>  '',
            'centos:7'            => '',

            'centos:8'            => '3ec346504035a28b9a6790a765ad8fab31a9896d762c77350e9368bd14a85b1ef1f9ad348ff46811802c1c2c49e43414eec7682b6f559684733b03f7a30251e8',
            'centos:aarch64:8'    => '',

            'centos:9'            => '5592811c8e30a09ece9bc389059bdc6ac56c30f48d6da8dc641cbf69b90ab28da55c861f5767096ed8a4382b3765c50c569a7988f658085d952fdebf404a86a5',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '303b773330c342d6ed3a5e26bb351a0b174ffb70a9f8344740ff5a1c4f84f1bc0ae845a3101a802eda27846fc41ff4085f76222ca85f70acac92c10a75b3070c',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => 'eaacfcb8f1b297a3381152ab7f5fc2e97008b118529cc3fdc8d28da4a0529354131b1eb2d4eee751c8403bfde58921e9603073578c76890f43780346823a7a37',
            'ubuntu:aarch64:22.04'=> '',
        },
        'capnproto_0_8_0'       => {
            'ubuntu:24.04' => 'cdbcdcf1963c0e741aa5dfbaef7aa14a22ae5db85925e06557ef22696ab731d7ad0ad4318aa68f07c8d2fcdfebea7c9f8d3e65697228f86ddaa0037ff0489a1d',
            'ubuntu:aarch64:24.04'=> '',
            'centos:7'            => '',

            'centos:8'            => 'b6a908d8f4a96d924082a2cb6de99adfb3f36b9bda7ccc3f0a3c35144b362e760c76645e46356da0968cda05ec058384666a3e118e8f680246c2cd3ef5fc9815',
            'centos:aarch64:8'    => '',

            'centos:9'            => '5e21ad45e7c32cc6fa4fbd40638be305169e32cb7e793a63c4c9d5256e701062e5ee1b29d6d6d91943e544009e9fcc89e86c982545ce42e4a0db430ae8c21b4d',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '', 
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => 'a9504ab13c430899d716123d8ba87744ef39b80ad5e563228b549112ccec03617fdf5bba667b913abed6d17888b7e6d7131d15f7bb0e5e990115d005dc016e15',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => 'fe8e8b9e954f6555a852e3ea6e15293d1ec57ad6117d23e26fe20db1ec892d3fe71b8d647f7bd0c8070175dd77f9a29ecb8500f52358f4441ca86ed0c8340fa2',
            'ubuntu:aarch64:22.04'=> '',
        },
        'hiredis_0_14'          => {
            'ubuntu:24.04' => '995a416f5574e2c9519b81decaa9219f82b8e3761920740e432eb3ae373261bb88a74a8bb8c9146714080124f272eb3939e968b8807cf7d9e489089ee04c9e4d',

            'ubuntu:aarch64:24.04'=>'',
            'centos:7'            => '',

            'centos:8'            => '305d18768ab72db6ea15633abfb1d06b04af07f2cc7b2f68ee8c607b43f08f0c0e102b748fef1800ec319dafef67d64fb4e2690d3a8a1fd462e5c17caf65af25',
            'centos:aarch64:8'    => '',

            'centos:9'            => '9d7fab589fbcfbcd97f654975d81a7ff5e84c7015caa7606de2198ca6bd84cf845cd18c13094238c562282afacfaa75315a28ae802cba03a8a0f5b113def2aee',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '', 
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '772321b446ce2c434b8e1615b9b7d49ea45d3c5873ebd159cfd43efab4893eee7d5998fc1842be55c45b01d661048a918e96f20ce52c8204d74caf92756f1f57',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => 'ef89abdeb7ff8d24ceac06381a3045db8e47701a8af4b4309ec05214048e824a488b6ba3aa884156d969279960f63a8ded5f7868529792421a2f09a535778855',
            'ubuntu:aarch64:22.04'=> '',
        },
        'mongo_c_driver_1_23_0' => {
            'ubuntu:24.04' => '3197c4a62be093bc5dc0a6ed89f689d0e39b639b83cad0414ca7e63f344ef66915e75dbd1aa0424dd2efcd55a4a7bc34e4c2bbb04b2475da482b5fe18d931e69',

            'ubuntu:aarch64:24.04'=> '',
            'centos:7'            => '',

            'centos:8'            => '4299b3c984c0167716f6492d2b1f46cf41079a40e932682bca7aa0deb7a298773e71efda235ecef493288fd1ed4e22b24ce463c8a7140da4d399321d1c1b7a41',
            'centos:aarch64:8'    => '',

            'centos:9'            => '508a00ef80cfeb0056196c5b916a80ce5ea2dc01b549a2f58730c49a69d3218ba51460b3ce614611b013ad4c1ea8acdd1696c3f45d37db58e997cf33c241f8c3',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',
            'debian:11'           => '', 
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => 'f588fa2153c5fd53665280b88dcbb49e1d22b68774122b49cc4539e5d85ca899372205bd6ce2a2716fe6d24f63ad7b496edce10012f50eb4244cb5b5b4301e37',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '9e5c4bfb2c06618f8a816f7e4e1a194171f4a049c4ae5cbf6acb960864f5d3c70b43d8cfac035c257e548d51aac5337c1e7d9600b5ae68012e0a41ae64ed1e3d',
            'ubuntu:aarch64:22.04'=> '',
        },
        're2_2022_12_01'        => {
            'ubuntu:24.04' => 'ffe4c7410e5ba8b122396c6833e8ac270269471089af7ddc26acdcc3e86261a758ad835d20127e639ee329945cab2665ffe2a77259fce8644fcae5eeff7ee27f',
            'ubuntu:aarch64:24.04'=> '',
            'centos:7'            => '',

            'centos:8'            => 'e2f756883a50e6a28a75b9f1fa5b983072e69ed07a39c63474697a44184f4a04e233cb5617aeef0df7b1417e9436c2e77a7c9e9882e2683875d3e1610188da65',
            'centos:aarch64:8'    => '',

            'centos:9'            => 'b79a900a7f8bac98ec641071f56da5be60159e9017c69daf0d1a55758d3ece21e4bb3fe2f574c3bbf52286747b23ebfd856c61fc64b4f201392397b900e39ce5',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '', 
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => 'c6c90db00f9f38b7607baf0d64f22940a26ddf61572b64e54bec83a67a9ebf7bb210c002a7cd96b92ec8155aa0c89558bcc0d2716775ce5595cb46bf80780e76',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '9ae3f42af6dabb5452a9774586c9d44cd0e04cf812977dd9198f69d840e592e8a00abf267a07fb13bf30f597e5758e557137459e5d181b2daff9c6ce4f088847',
            'ubuntu:aarch64:22.04'=> '',
        },
        'abseil_2024_01_16'     => {
            'centos:7'            => '',

            'centos:8'            => '3daef66123551be2c51d51ec2e58483652dddf3281d1b349f15ec90653b6a8a36599f585aaf821d492c83fe186c3c2ee9348643d8d3c9af208eb9ef9e163151b',
            'centos:aarch64:8'    => '',

            'centos:9'            => '5764478dea082feb72b9b70a0c79c5c394821045c1451d9db7cc1a476ad8e5ca78cd254f3804bba9b4007818a3b14de9d8e030122c8d8359deadb99ec2eb4514',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '6eda5ca283c916578d7ac9b307b3b67f92f8fced478b65b347b00c67c58253084b9362c9690fe639e46c3e600e2e8fd27515a64b3147e76379cdebc48a877d5b',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '41be0b0de158fcd053d6d9f5d6c01dd97126049ce2935a002a7473d07c99d640fbc7f3db4895394c99067e41fab1737a2b1d6e4ab0ddf389109d267e039bab0d',
            'ubuntu:aarch64:22.04'=> '',

            'ubuntu:24.04'        => '311439b2a519950cecb9a39df9a4488b4740cdddc4312189e27f030e20a1053fa1fdea3d90741ca8ce424dac67e50bf16d530ed1311c6e54d9860d90d69ee583',
            'ubuntu:aarch64:24.04'=> '',
        },
        'zlib_1_3_1' => {
            'centos:7'            => '',

            'centos:8'            => '78eaf8c7d6397138ae32d627805bf5aaf2db50e15717280ae72a7526f10d9d9e50ff190dea2862e8dfff97b82d43b5331b5ef4b31ae388ceceaf67e13a922404',
            'centos:aarch64:8'    => '',

            'centos:9'            => '4a2fef2ea74be0a2904bd33b852ff6cac6dc52c9cb0038fbd2bf278ec4cf04dfb5daff12866c0f1080293cbba33621175079d4e4eeebd79e8a389738573e1d46',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '63d7441586697cafde850b8562e6f712cee3f901e77fd0272167687171382e734669ded552341c9e23795c17cf39935385ea16dc6197f261663cbde92ac2c7c7',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '57fb366370035942f645ac3f413f76eab5734cbb1e44c0f469ac056d86657b1505ae497faab6df1ccdca77ff1017c89655e71385b71acd5dc5ebbbc26fb2b257',
            'ubuntu:aarch64:22.04'=> '',

            'ubuntu:24.04' => '558afd98e2561986582483aae40a35feabfb860bba68f6d5705d5ec26f3230061e9af4ef6db2137dc06a01c8aaad3f548b6b13d6cbc918e24152b3120ece8a6e',
            'ubuntu:aarch64:24.04'=> '',
        },
        'cares_1_18_1'          => {
            'centos:7'            => '',

            'centos:8'            => '0a8e7beaabd5afc328455149042a5dd45fb6246b694e96a60ae35e2b74df48ed21566384f22785e534f26bf309cae15357eafac4b817871e75393b8a0adb7ea5',
            'centos:aarch64:8'    => '',

            'centos:9'            => '2709c947fea53c2a3aaf7730935dd31bc3956614f71acc57f365c6566ee0d6ecf6f9808a49bdd5ac074e5ae267e5148f574388cfb4bacc4e6da9e1ddd0ee7e29',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '', 
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '647fe1510d389a34c34a1d035585c07d66612846a8f184d33fc2be859af5801c7ef3b398d138d3d47c3be898d3de6548be8eddf874123f8c87680a4ac25ee447',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '48d2e2d9a141b34688435d9bf8e6a1aa2132d0b247ed34da0fa9434d90fecb10a658b7e6dfb6113880c0bc72d80ec029729118510bb609d4b8394ccace2cee54',
            'ubuntu:aarch64:22.04'=> '',
            'ubuntu:24.04' => 'a0d169c14109f73fde40592526c2cdce6b3dc6c73d9a2bccf7d44d0493b1c9563267ef796281c16cb5b404125f2c080f572444e37ed9c8a96a94e8b2ea67ba71',
            'ubuntu:aarch64:24.04'=> '',
        },
        'protobuf_21_12'        => {
            'centos:7'            => '',

            'centos:8'            => '1eb322b6b57f2adfdb3bfa0ebfc1f6e9fbe489f067c40923735fdf74ac6f9b46a1367d730c4aa8ed45ab21817f12d1d69bf7840ef4993ada31be336c172107c6',
            'centos:aarch64:8'    => '',

            'centos:9'            => '07a28a4050e935e78d11d3385ab59671599d38a055d24276c49aed2e379aa26f7f59e45fd0df6fce51657450bb241780b1048a8def259f9c3ca21556f82af468',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '', 
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '64e318160f0702e693e943bf40d5463dfb1437e674f0b269fcb63ddf93e31fca1fa4726c8bbc0dc326c357a01512dc1716252e5c1906ab80b114bf0d5819e584',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '2133ac4c38353b6bdd46e47e099c123717d83f547315fcfec4097dca7c6ac4e834c9391753024c0782682221f696d8c95b619a0042a60597926da18f1d287801',
            'ubuntu:aarch64:22.04'=> '',
            'ubuntu:24.04' => '17672a86fcf504ec7078635d9753bdfc16b7498a239f46171465dbb3af0e4eb0ad3fbdafb5b122c6966b9435b4a4e629a29555553d2ef9be2c5bfcb2e30804c3',
            'ubuntu:aarch64:24.04'=> '',
        },
        'grpc_1_49_2'           => {
            'centos:7'            => '',

            'centos:8'            => '0485da74ab2159b9207c3b2e3c1fd8165add53399ad59ef4a5efff2711738bdac9a7c9c2c08eb45c0d062fac47fbe76db6a5b80c9068c69ae2f5eb86d4a2cf28',
            'centos:aarch64:8'    => '',

            'centos:9'            => 'c7d9a3b8958c83555b90fc70a808a1f0c071264b74650580573595f9e70aaa9ad872f6b4c2136c2736b31f3de2c486cbd135fa465149b52853587151d87a7eb6',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '044ad1c97b9e1a1bcee8f1e55ab3e0bc8629322a3972d2e4228d74e1b9c2570f6edd216191e85cb2b49d944f4f48f9306416d219563f1bec30282030dc03031e',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => 'd756fcbe5a5b46ca4a0aa575fdf4ab5d3dcd6d71b65de1029d176ef79d85d41e3c3d866cd3f7dc8ef909c9973b39c8b23d4227f56062037bc9fe46679e99f0aa',
            'ubuntu:aarch64:22.04'=> '',
            'ubuntu:24.04' => '9f7a539d7f12f8ff73cd6dbff78d445b830abf844bd7a7a90e513240f6c15d514548228781a7c9fb94554b9ef9ca9bd29163d5b341644c8d5bfba7b490d9eebf',
            'ubuntu:aarch64:24.04'=> '',
        },
        'elfutils_0_186'        => {
            'centos:7'            => '',

            'centos:8'            => 'cb087e29ff70ec8b650ab9d52f731fcd34fda99e3dc8d6fa2160e88e0ff5b539c8b5dbfd3254e5a5cfbfc51e6687bb13bbeda99fd02799ea5ca1d696cbaa52e8',
            'centos:aarch64:8'    => '',

            'centos:9'            => '5516d5256dbc104c662575ecbc42c741ca4dcb4f44fd1c5a7347d848c1b74ee35266a1babe8ea61eef930562e8e4a9e05eaa6f03b5d47f4632d1dbcca8fc39f7',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '', 
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => 'e2fba1c8448065af1ede5e34b62919b8f61a12cc64e5d4fe6a8da98e59b8691f60fc19433b76dac8c1a6ec55f7c0723c080c6ed0148f267e44e158e9d7c21c8e',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '5edbb6a02725788ef405b0c5282cb1daf92f9e9315fa849ef6fd061e9de3254e78ba0c312cbd910d5c571d10120d21d4e9f3a1e3e6319fbfa48e5131dd4b52de',
            'ubuntu:aarch64:22.04'=> '',
            'ubuntu:24.04' => '8f586b8682a7fbd1b3e79d37a496fe7a04015b1bb26e6c53622a7a8f2f3a32eb79bc4f9184fe9fceaada164cd99fca7a6059f4f8b3297eef807c818a93b856be',
            'ubuntu:aarch64:24.04'=> '',
        },
        'bpf_1_0_1'             => {
            'centos:7'            => '',

            'centos:8'            => '5e52342a4d0d5e9a04aa760184d22ebbe87cb4adfeb708fd79539916f6710ec5da96ec954807e592d91cd08b9cde25dcb7192f76e3ada4198709b20414bc027c',
            'centos:aarch64:8'    => '',

            'centos:9'            => 'e4881932ad7dc7bd64dcc45de3a56127b0a537da9b526d62e4144f98a08497f85dabde3a9189b4cb0528d4af96f2973f591a7cf4e96e28067b538c616feb7493',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '2c2777b4daa76dc1f4c78eaf86c3204cac2aa46a3985063b5cec3b28febc2653d58af84d9537c6bcf2344da91750c2f427ceebcc11e93ab5869f28f59347343c',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => 'cfae1e4ac98d5166e2bf76c8a61f4924a8920420a5455b8e2ee19f9fc5af9a0ffa08a87c24fb052faeccd55cf8f420fc29f699949100bd77649bc37e6c78ba61',
            'ubuntu:aarch64:22.04'=> '',
            'ubuntu:24.04' => '25d44d8146e673a17f4934b0cf727d45e72d49711cf02bab453e4cfe1cb0e36d14d510b98c4af684352ec5842cd05d3a972798ef48f342c4bba8c58bb202859f',
            'ubuntu:aarch64:24.04'=> '',
        },
        'rdkafka_1_7_0'           => {
            'centos:7'            => '',

            'centos:8'            => 'a380533fe1bcc38441e77bc74c4b7cb36f280dffcd396f4d7a59c9b8ff09e57f48af965728d1aca65313dc0ac9d0f429f74d74da5be4db37681a88074ad575b3',
            'centos:aarch64:8'    => '',

            'centos:9'            => '5026f652579285a7ac629f10fd82761294ed9ca5f4d776ee57f1430d182453050a51d9cde3aabbd179fd060df4243a48aa5b76f20fc7c2b4a734698be1a6a922',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '', 
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '9965b15554acbcb2a9eca9fa6f293b35ac9762216707397337811aeb0c50bfb312f052f53d13f63996467b97537fc86a704c43f6ff8a6c855978879a19bf7e07',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => 'd208cb43dfd9887fda5e727f2abe9c56e9b689e1237c0185c68b0d58bb957d820479ccae7f49448fa2d789130beecf3309dd84488f94b3bd3f4351c60616897b',
            'ubuntu:aarch64:22.04'=> '',
            'ubuntu:24.04' => 'd3f24deb0e72c5158324af20654c816f157682b3a25c07c1dcb4a9d77742d306dfc1f8bf930b3b958346ab08f3ebd6a628f5364f3fca44bcc6c0d3f08e034b18',
            'ubuntu:aarch64:24.04'=> '',
        },
        'clickhouse_2_3_0' => {
            'centos:7'             => '',
            'centos:8'             => '45c4dc5a18e4b3b3a335c7bd490f648e146f23e7ebb1ef5c407e7e2c70ac02581d362e050d38ec7fc21499ae380e72a83741df07ffdcf654728c6b123488ef1a',
            'centos:aarch64:8'     => '',
            'centos:9'             => '289b5bf8e470666fd0010f103e384b762dc412eaa49d28bddc9e335e41f802d33e1e7db3e1ad75328f6bf7ef9d860828f9e896dcfe18064f2503b7e7e01bf1a8',
            'centos:aarch64:9'     => '',
            'debian:10'            => '',
            'debian:11'            => '',
            'debian:aarch64:11'    => '',
            'debian:12'            => '',
            'debian:aarch64:12'    => '',
            'ubuntu:16.04'         => '',
            'ubuntu:18.04'         => '',
            'ubuntu:20.04'         => '7255146bd59e46cf3c395f079c93430224d37123cf5a336d94595b8c173a67e972afde819027b22b994924a927a83c83cb390db04de24a0fba26a966352a9ade',
            'ubuntu:aarch64:20.04' => '',
            'ubuntu:22.04'         => '111034012c03420235c9f114261640e9cf32059d67afb00386307744eacfa9fa8200ad4c6b54ac616882d4848eb702955a48199b2cbfc710a6813a251b561651',  
            'ubuntu:aarch64:22.04' => '',
            'ubuntu:24.04' => 'f1b5c0ee61f0d44811bddd2098f220127cc7a25dffaed616b0b333d546658077594c8408d50995976ce67d1e657cab1fe489a72de8ef32bc00404412a6bb6ed5',
            'ubuntu:aarch64:24.04'=> '',
        },
        'cppkafka_0_3_1'          => {
            'centos:7'            => '',

            'centos:8'            => 'bd8aafb8eaa25fa5d3460dcd2bde9347d9f03e7cef5f85a92044f9b6996a53adc89f5dafbeef7518340f4d6b15a495ae4a976fc8c0f075a5b8ebc83479f7ee7f',
            'centos:aarch64:8'    => '',

            'centos:9'            => '32479d8314c259e96870ebc2898b18126a3aa2c269d74d5a4e558e38d7e36129964f395fe096e14fc9c0db2ca1b22d4bf969d8367941ac24a55c4b469d220f7e',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => 'd133db75af256420975e47c3321d3cb86f79fd02433de7296a75e3d0ff37fddc18c4ec565a6d02f1f4223e12079656a334b897c0c2477820f882ba22222d3553',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '22473feea931f9bb84dd212c0c2934e93aed86183798acab137f6045849a9eeff0834b7d2361d0d6a1bfe7d59bf09f15f57e8e974df43397f2534cd0468d5365', 
            'ubuntu:aarch64:22.04'=> '',
            'ubuntu:24.04' => '44e8dff39862672f9b3309ba9b3f1a93d9d4c404c64ed856b42a5785982c0123c4b229c1c86ae09ab5da648355a52c92490d62fa626f2d9331ac3ac088ece486',
            'ubuntu:aarch64:24.04'=> '',
        },
        'gobgp_3_12_0'          => {
            'centos:7'            => '',

            'centos:8'            => 'c25eaf82434917805a1717ddfe2d12b918a06a89c163881819fed7bb49eb1fcbb19068644ab527e4472131836f3ff8039c8d7d4c4f6986244a0098758af9c18b',
            'centos:aarch64:8'    => '',

            'centos:9'            => '7f172e7dc925cfac17d573bf45a419d89587dd607b1939be411fd35a7eeac56191b7ab51299c427f43ad50d87c1452257de0376569e78787d3d664d14747b837',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => 'bad361a34bb8759dac3c932d747a5ff89172db96b1c7d7fe17675fe5bb8a40290c1c7de2c972283730dec130bee4f9127192d684409996a30872fc986dc291f1',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => 'f36bd758c818ac5392d32278757e28901407557b76efa00aeef9a05858d5c3429a6acef620b5344c22bedff2aff5406fc5b3e86ab714e7e92777a9dcd345b7fa',
            'ubuntu:aarch64:22.04'=> '',
            'ubuntu:24.04' => '22f843581f2295535635edfd715896579d5a719b92f24e030cebdc888645e42c575f3a15188da1781cb322d11b140cf06317f42db1494e50196d68b36bdddf8f',
            'ubuntu:aarch64:24.04'=> '',
        },
        # It's actually 1_1_4rc3 but we use only minor and major numbers
        'log4cpp_1_1_4'         => {
            'centos:7'            => '',

            'centos:8'            => 'f4dfa3c19f72035037ae56e47559b0679722ac9e2f5638d92d1fe4ccf9e6d4b007566edb0a3fa6bc1416b39d9f89323a82161eb2d8964d257f1cf7df66445cf5',
            'centos:aarch64:8'    => '',

            'centos:9'            => 'cd507f7a57e376cba0ff4c2c390f6afe61d943d84c197fbf434fd2b695dbb5f7ddb8046bc90050c083f0cde6cc1056c8914815f2f1d0afc214693897c3aa53d3',
            'centos:aarch64:9'    => '',

            'debian:10'           => '',

            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '',
            'debian:aarch64:12' => '',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => 'a842f359786da92e05408fefa8ac3a21a06e405b016623fcf800840833495b6c1847659b424e77d8efd29c9ff2ed64c135ab68de345861d1e5992bd0bdcdc452',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '339e170a34d92c8b0ff032c5cf534e29c6f8fa3cdea70c5dd49da2fedc65a92fb1f3494947f992d1cf7d0dbd008b2066f4e1db53e91384510ccb78d457a9e5d0',
            'ubuntu:aarch64:22.04'=> '',
            'ubuntu:24.04' => '4a730237ed467e2e4d6035df8f1ea430b0a37bebbb0d344cb697e128cbcf7e594ec9734800cd3f039dbd8bda8850942a6d0340e3951c74e6e3caf860f6001a20',
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

            'ubuntu:20.04'        => 'e21605eadf6d77b11f1b06ca4f763d24d9f50f52670a8d86684ed1f63cbf3c5f80e0e0402cba7bf5e5eb43e4975ac15b8f58d8fb3e57ddaf2c46f86eb4acb770',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '21cdc41e9458f2342401678d29c29176598f02d67adcc004502907068a944015d5789a41d72f8c3eb0e6e48010a421f31baf24b8d8e91db98c930c329eae12d6',
            'ubuntu:aarch64:22.04'=> '',

            'centos:7'            => '',

            'centos:8'            => '0cd23ddb4274feb9b7d3ae54061a1c3a1a9c099e9601e2b4b475ac000628c07e1a8c21336306db4385cc776573ff00b05c3ecab87270a3f25b65aa4fe15c9142',
            'centos:aarch64:8'    => '',

            'centos:9'            => '67afc18ed69c7a820de0aadf52e147b1dbaba48954a7fe0ad2a86581b938c731b04ca8e571a6ca93e6ca265b85acf2147a00ba4f970eb481a8bc3e345c10636c',
            'centos:aarch64:9'    => '',
            'ubuntu:24.04' => 'b61e794c9e0ea55b0614ba5fac18eb9bc4257b5d808563d41a3b4b2914454f53f058f7a97ad2daca3dc3bc79ada0fc3b9dee42315c561ab90abb27db7b46a85c',
            'ubuntu:aarch64:24.04'=> '',
        },
        'pcap_1_10_4' => {
            'ubuntu:24.04' => '0b0f8610a71f6faeb9f1bdf26325d00571d6a0234f4dbd69bfd28d8b16fc1358f42519054302a8c295a132f7bc88ffbe9adca792dcc0678a84cd2ddf5d340aaf',
            'ubuntu:aarch64:24.04'=> '4c95d237d4653150e94638311e3dc0b7dcec15284a62ca1ebc017955c857c80b1f58ca5b608c300d9485b4607a92fe128d755535757d9cc4481944b0cf34723c',
            'centos:7'            => '',

            'centos:8'            => '24c8fa4f3e5e80d9391605c8e50b4abddf28932edd1f98d4363b43b911ce0c8109bad1944fc4e2474444c7f3dd994b2568ec415a29f1078cd79b404e0a5b7651',
            'centos:aarch64:8'    => 'd130702cc62add867c45c6f727f9e0c40a7ea2c3fcecbfe03e47668112facbefb25b2abba5606cda21ce3d7bb09d07024447f5b8cf316d8d7f5e9a0de74d3a32',

            'centos:9'            => '9786ce36678e53c92c5a6780933166a330184f145355f912f591bf9547cd036608b055f65502dd27a6579bad4f4f19e6d306164bda8b0aaa0a5c30e53c25ec89',
            'centos:aarch64:9'    => '08fd658e3d3a7ec3696b6e6700352e82cdb803214a5e76b2a463e7b27f137efdc502efc9cb5abe5d2ae38e864393bbf43b03acb301ae9e444516a53295d8161b',

            'debian:10'           => '',

            'debian:11'           => '',
            'debian:aarch64:11'   => '',

            'debian:12' => '1cf204995ae1a769679a3817c4380804f849245ebb9241d0b3ec36d6a90a5ffa8feb015a9a5970ce3594d64d4d71aef9b6f2240d62f1820c4cb1dd2368452948',
            'debian:aarch64:12' => '25fe6824e579723269cb2b29f86538db0e935fe24867b771f0766071c2e36ca61c70127fd0edbe277f693dc1c767ae2ab2d346a777030506bb6240c1baebdbef',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => 'b5348129fd1411f3e9510599ffa87d6da45b04e222367318701b729aba6c8f1e4eccbd324477d7347a4b227f695f968006423096dab9963debe1cf1c7b5a62ed',
            'ubuntu:aarch64:20.04'=> 'b99ce2f98a528e5513bb1ee7f51dfdc91f1e5cacc088e834bcf86ef0b6b71714eea5bb27a95720be2f0fd2d805d902fa5d8ec321c2f489f27f2fa04d2d96d168',

            'ubuntu:22.04'        => '2843752dc12cbd3606f4ee2639387cbdd9b89c03896cd0efab657ff24b6d5d24aba3062fc19d65d9d7a6e34fd72048d7e213a76d8c1c827b5097f611c8f275d4',
            'ubuntu:aarch64:22.04'=> '3a28fd46071f64fe89db933936665bb492654a7cc1c641083f73b67b9338ad4340830d2222557b6b059a6c253291635b0cf3f9511bab45745fccba77f8342c84',
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
