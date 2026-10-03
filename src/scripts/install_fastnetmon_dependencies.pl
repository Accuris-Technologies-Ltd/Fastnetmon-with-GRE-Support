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

            'centos:8'            => '',
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

            'ubuntu:20.04'        => '',
            'ubuntu:aarch64:20.04'=> '',

            'ubuntu:22.04'        => '',
            'ubuntu:aarch64:22.04'=> '',

            'ubuntu:24.04' => '558afd98e2561986582483aae40a35feabfb860bba68f6d5705d5ec26f3230061e9af4ef6db2137dc06a01c8aaad3f548b6b13d6cbc918e24152b3120ece8a6e',
            'ubuntu:aarch64:24.04'=> '',
        },
        'cares_1_18_1'          => {
            'centos:7'            => '',

            'centos:8'            => '',
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

            'centos:9'            => '07a28a4050e935e78d11d3385ab59671599d38a055d24276c49aed2e379aa26f7f59e45fd0df6fce51657450bb241780b1048a8def259f9c3ca21556f82af468',
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

            'centos:9'            => 'c7d9a3b8958c83555b90fc70a808a1f0c071264b74650580573595f9e70aaa9ad872f6b4c2136c2736b31f3de2c486cbd135fa465149b52853587151d87a7eb6',
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

            'centos:9'            => '5516d5256dbc104c662575ecbc42c741ca4dcb4f44fd1c5a7347d848c1b74ee35266a1babe8ea61eef930562e8e4a9e05eaa6f03b5d47f4632d1dbcca8fc39f7',
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

            'centos:9'            => 'e4881932ad7dc7bd64dcc45de3a56127b0a537da9b526d62e4144f98a08497f85dabde3a9189b4cb0528d4af96f2973f591a7cf4e96e28067b538c616feb7493',
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

            'centos:9'            => '5026f652579285a7ac629f10fd82761294ed9ca5f4d776ee57f1430d182453050a51d9cde3aabbd179fd060df4243a48aa5b76f20fc7c2b4a734698be1a6a922',
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
            'centos:9'             => '289b5bf8e470666fd0010f103e384b762dc412eaa49d28bddc9e335e41f802d33e1e7db3e1ad75328f6bf7ef9d860828f9e896dcfe18064f2503b7e7e01bf1a8',
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

            'centos:9'            => '32479d8314c259e96870ebc2898b18126a3aa2c269d74d5a4e558e38d7e36129964f395fe096e14fc9c0db2ca1b22d4bf969d8367941ac24a55c4b469d220f7e',
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

            'centos:9'            => '7f172e7dc925cfac17d573bf45a419d89587dd607b1939be411fd35a7eeac56191b7ab51299c427f43ad50d87c1452257de0376569e78787d3d664d14747b837',
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

            'centos:9'            => 'cd507f7a57e376cba0ff4c2c390f6afe61d943d84c197fbf434fd2b695dbb5f7ddb8046bc90050c083f0cde6cc1056c8914815f2f1d0afc214693897c3aa53d3',
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

            'centos:9'            => '67afc18ed69c7a820de0aadf52e147b1dbaba48954a7fe0ad2a86581b938c731b04ca8e571a6ca93e6ca265b85acf2147a00ba4f970eb481a8bc3e345c10636c',
            'centos:aarch64:9'    => '',
            'ubuntu:24.04' => '',
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
