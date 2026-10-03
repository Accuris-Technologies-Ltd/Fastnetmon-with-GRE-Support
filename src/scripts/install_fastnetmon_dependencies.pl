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

            'debian:11'           => '84aca3181c258915f4d9da05eb304b6528263b09005d005741e6c2eb9bd32dcb4fa5f591986d9c5eb81f4428a3edbfa6df3fce785cf324819d2864bcf1be6262',
            'debian:aarch64:11'   => '9903028fb2c93a0cbc46a2b84ead7465a5da82b1908e57b2a4e7e2afb192bd56d7f67f91beb79beb4f5a91946a259e683ddc473d66cb198e122fc13dd4497c6d',

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

            'ubuntu:aarch64:24.04'=> '3355673ba943a7d1c1263c880b0065aabf14a98ef24bd363b46ab437bd8d496374355dff112d057d6163732321db77e8a82b96422e2a4fc4bf609b99db8b8d20',
            'centos:7'            => '',

            'centos:8'            => '9c2d0e6f43be3630851840a511b0c2442bd355f35e49047085d63b99a3225de9af66be8305a9252ad97c31ac442184b2b42d93252e6dc684b20f48923dc06b4a',
            'centos:aarch64:8'    => 'daaaa4fdd66f26009c7f60c997a8351d58fafd1e88edd9bb60b98b92169d48d2bf2db9d943438565180bd03ef359d63e51362910bee0c9cc4742a54a65eb6c32',

            'centos:9'            => 'f0328f000f6103af349d03940c102dede0e31c8a9ba6c14da45069467c85eb5622a7f9eeda757b79f0dd2d3a69529462e84ad3441808fb25539b1195e0606e5e',
            'centos:aarch64:9'    => '7488f40b8021ff32e9198831c06a1401b377e397283ef24193dcd0269ca3e5a44cfb4bc57b370933d2fc0134c7b1035b7bf25353aeb8e7fe809e81d2426e2670',

            'debian:10'           => '',

            'debian:11'           => 'c5060c4008a64b25c5c950b405f6bf7c751eeb37180899505fbdbb77335fe6660f6db3c219583f25716ea3953f4adccfe5261d6dfcba3baa0eca8f2e5e220afc',
            'debian:aarch64:11'   => 'cd59dce9d3bbf4f2ce31d890e4306c7c6ada74916dedce7266d8da8c353de93629924f3b1d007c7dffd1b1322f8de19cce44ebd632aba4fa1b67546afcdbc2ba',

            'debian:12' => 'c69967e8b39d3ac5df5944d1ac4fdd39b713a161aa73bb2fc034f06702c635e7b3a1a27159cd44deede68b0d87dd769904b516bf7ab9615ddeaa30ea0f646a98',
            'debian:aarch64:12' => 'd4133ed015308b426fc159536c424db58027801cd90aaaf1314503c8e079f5c933543e491096fc03fd22b97fae8042be1faafe745ad0a0ef599e410d53196b32',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '5a3d4eb4f5449f7f4616e9589749a4ce81fafcc9e738896e4a59185f88aba45e93fb48a49b95ce6deb4fa49fb5d0639c448330748ff3badcf5d0c7de30312e67',
            'ubuntu:aarch64:20.04'=> '42f519985a0c34510ccd287cb385cb8b72c4243267d5de3df5e8065b18a940976ae040d156d0d36e7f762be7882324727b544959491960e9f0ac4f80b41e032f',

            'ubuntu:22.04'        => 'a4a84da061cd3e1645d1d799ba55f8725f61aa9bbeeefad1fcca7c369fbbd74a68d9af5d74bf4e80c2bf686a670b0e242fa67fed16226a0ae1ee2c2c449cbf71',
            'ubuntu:aarch64:22.04'=> 'cfee285650490284568ca011c2365e0d77b8e41f41e39fcadea3712a1b436676728d4a2020f28fa69f7c4d11a5b362c847a60dc00b4547b8f1fc71f0e9cdab9b',
        }, 
        'cmake_3_23_4'          => {
            'ubuntu:24.04' => '50205c99d7b7ecf5a5cadc078ea0b6d6903a9ebfa7d7468ca9361e73ea7589fdd4a16f8ba09ca00dbb4a07e132f581288dcceb5069cd741f4935fe0e1da30ef5',

            'ubuntu:aarch64:24.04' => '1f19d5bfbff5f90980bceaecb0969ea69416436ceb45f951d43f82cb8aaebb21e082d265901799ab73d826c32e82c8d8cb5b0a86064a23dce35a0a1c5c8bd32e',
            'centos:7'            => '',

            'centos:8'            => '74aae21b4da6e997f4baec57fab25a237b7de959015bd0d9869d55a6a80a3c427f2ed701727e10e3ef08d8c02b2181968aa586005f08df03b04a80c2351514d2',
            'centos:aarch64:8'    => '5b5808cf3413cb298ede41308f7bcc83a3eccef409062831092b4f4cc26e8547ad2ee83232c21459bab497afe68d8f0fbdaf03eef8eb7b93ba577104aeefad13',

            'centos:9'            => '7b8a768d3aa73a44e999e219b3c9fc549d64df9c4a670ca3507f2804f5d6019cf6100f705c6f5bb55e59714878e1928395d28681f8aa36f2ffbef92fed27b327',
            'centos:aarch64:9'    => '7b68e7cbbf96051cb8dcc070fa40f62cd439c53ec27b7078197d2fcb3deed08626ac39771d9fc3f2d6fc2e2324228063a723a3ef0f26cb2d1eca863894151050',

            'debian:10'           => '',

            'debian:11'           => 'b845892b135246b76853d8428e8d31ea5a82b2ac3434726cfbbc0e636e392463b2f29392d1271a6a46c1362202a6a436b70dd76ea27f3aa328376162292682e1',
            'debian:aarch64:11'   => '0bcc9f6e2678d25fb3c17f114365040fb28bc0a2987c9635e8a299b95555ae8c7c3a0937cb20a682408366f7c6d61f0fd75c3aad6f721f7ee8240032c83c99cd',

            'debian:12' => 'bdf6fa145bdfe0cc779461d8dc6798c09058f4eb8d7c7017a304f1bf30b315da88d78831c980db4c281069cdecaa03549e82f3aee201561261c17ddfd6fb988b',
            'debian:aarch64:12' => '5596bacbc9673637cea5017d90762828b82a4ca8b43b2caa26465e509555a81e5700ee19964e44daa7ffd7731ca76685a68591d725559c7bad3f79cc2f6c87a6',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '5e4d2a87c761db9dc3d74969225aec0116ea15b5776cd36b606c57f73e4647685007a447b60f1bc7857233e44bb38940cbe5bc036b6b26c89b3da11bef015bb2',
            'ubuntu:aarch64:20.04'=> '512824abf2c89ed04e495b0f27d2423e47613ac1972bf66c04d33d892c21999a96fae4a6f51288d9ee536c7919435d18e1ddc53e10cbe2a244f2f2c2adcfe310',

            'ubuntu:22.04'        => '1be59fcc7b3d89eb9fcd60b3af47963dc96b96d2d67ad849bfc1ae1efb293e974bde25ca60b6aebdd35f6fdf1b88674641696c5d71e86c6eaca31e3d26042969',
            'ubuntu:aarch64:22.04'=> '7585705bbac730886147131352e61268ae042152084ab7698ad22e077ba644ef726d5f8831becfc325b2c49fa188ea234246aeaed408d069908bef72c39eb5dc',
        },
        'boost_build_4_9_2'     => {
            'ubuntu:24.04' => 'f5242ecf5671cfa9b8e290c9f5e87fd1017b22b58928e770a67fe7b57915776a1b2f1eadf6abc45c6241ad697ea1092896f505ebb3a5ae18ec9eedf836aaca69',

            'ubuntu:aarch64:24.04' => '55b01943bc9d82cd366b936098f39d80a0a5b7f877b5309da2a35f93a2b52b320bb161d02ba13d01680a923a858b02b014f664938081a18ed54d7e56397cb128',
            'centos:7'            => '',

            'centos:8'            => 'e847b94d7fdf9cce25c64e03151cf44ff950c5dfb332bc7709de9677a4f25a6b97cc871b709d29de0315069183facb358ec132327cbb5eb746a4f6aea4bb06a8',
            'centos:aarch64:8'    => '108271301e289fa5c72063586618edb3778b35f0fa9c9c3dbe5cd91441744fa8cb79f31216b6507f1df1d0c486f0ff9d444b59d576619363fb2dbd58f46acbdd',

            'centos:9'            => 'bb636d6f5e27ba347ec207462dd0527f4ce888a9b00d863e43a18e115a05854739daefcb31129ee3ace5c7bb7aab74515f1751c31033c4b40eabd2f3159afa44',
            'centos:aarch64:9'    => 'f4a100de9aaf5df81ea03ceaab4124e4876596907edf8320c565228c402d722e5d33a106b3a1163f37813ed8ee47c25e869c42d8e310bc4c50c3e7c9625dc9ad',

            'debian:10'           => '',

            'debian:11'           => '0fa41179410cae607efeae7d24f5d9b9f37764ca457bef96703981cfc975c95cbc342913ca0bf2a5e55931160f6801ce1719cd231142c4a28dd39e5fbbf044b7', 
            'debian:aarch64:11'   => 'badfcbab254b9b17eb4ecb4010c6df12b1fffe971db9d8c9821d7a047ce5e3840b5f4655e01a58647007dc0241548c73fc1500e4009eca1a3272de51553bdab2',

            'debian:12' => 'fa1959250f1e1a7a042940180ca06c2d064e2a4cc677f5d48a3788853d730d3d50c0442efaf4fcca56f34a949e406ec5505b0fed3c99ae3b7ae9b1d0fff9f961',
            'debian:aarch64:12' => '7fe09f2b6296cb86bca2fc99aa9292c96653ac07e022d8eb1e31c37d6d186bf65c881f39cb6dd2150ee6c38da034897fa3cdf5024456ee64f4342dc5385cbc9e',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '0f687d90e4322afdeff74754d32c14d437e7bdb143cf5678a8550c553794306b26572edf0abbd5df55d8072b242b08c9dcb453d1937579c62a59faf82668ecfa',
            'ubuntu:aarch64:20.04'=> '42ec77e1308c4d2df1526efd0a01c0b25a419bc9d176691c0f7832b85c937cfe5310a61c13b335a9d545a95ee7b6d2ab1565e2c9ff58d0fde2e2621a85b01de3',

            'ubuntu:22.04'        => '1c71bd9b16928fbb92a293d64614930d88c556207ae5d9e2ee94b3e63a07c649fa43e4c7b909fd31adc3bcc1f5d74c09794490a4c4e89fb9f6c0b91a5a4690d6',
            'ubuntu:aarch64:22.04'=> 'f1c1d772874a2ba1ad9dfec7f90fcd82bbd439e3b7c2f7eaa7fdd52ef8f08361e387a7a47d8203eba4b472ac72bd28771125d483d5769138b3f69c00be2858b2',
        },
        'icu_65_1'              => {
            'ubuntu:24.04' => 'e89700dbd08d5e7cfe6d438b20ca1010bf92f523905c06ed7b2a87d8d45521a39edcc6d86e1a555c011f75139287708f4b777e16190f3b0dbd9aa7967080d64c',

            'ubuntu:aarch64:24.04'=> 'e92c0e0ffbb1f02945a751d25abb61851b750190007144e2a18aefbb73cfab7c20170938606d6c9b7b8e777808ef71cd1b1b00a726f2ade2c34c0941f176ef9a',
            'centos:7'            => '',

            'centos:8'            => 'f12959df4b0befc56a5faba3a9c6ef1b2d3990d141571e137d07b509cae73a09a635c6f17af008614120a09a4125d915f1b0ddb4ce9ca80542f6c4d125032faa',
            'centos:aarch64:8'    => '5bec2bcb091588f94383e465b2dccef188871bf5aea0bd384296aa8dc3053547e3fbf396c13ad60192c461eaf192746d4f51616ba0ff57a42ef9d2bde557d5f3',

            'centos:9'            => 'ffd8fb3b45920782c462fc777e80d0ef075838deac6e2a344dd72c8aa4319ffeb3f706825502f872e5775c2ad681ad59494627de2c105fc621a9259ef6346741',
            'centos:aarch64:9'    => '70647dea47f9f9fe7b6a286b92f4bfefd08acf9efa5bd5fa6b201a232e2c89cd718cc19311f5d44704ad84349f2931d78aff3fa9ae2db35a14d6d9b6a2ff9de0',

            'debian:10'           => '',
            'debian:11'           => 'e974a066289ff79156e60533766b899085dff0c95b20a4b5a88848a91c441bbba298705009647ba950b04dcc53fac7aabe6d8fe17255cf789dfe9d772bed99da', 
            'debian:aarch64:11'   => '38250f41eda549d0b68ec34390c110cf36494da524c031dda8432ce3b4017c58e15fb4695cb93c78fe05e4ec6be265906546e489d9d63519d19b1b3b584f5522',

            'debian:12' => '436f099f9c6c6f9b14e124c7455ea5aba5e041d5b641bc1a3ae5fe48a75f5259015ee2d260855a3f0cc0801d948d82909a9ad04dedb63e32f77bc3f1a916493b',
            'debian:aarch64:12' => '9c9ab4965656b761cc5b49c8049bb3c201276cab8202f3d9789f82298b303ce9874b24b87f0790be5a01be131ce005f3e46d6882601daa7ab33d20d0c01857f0',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => 'd60d1c071eb6966533aa456b1b1ee5da2ea1286687a7e2cf7dada59b2d398dfe7cbceace030a8d4c57c0e621249f0ee7263c10c1fe52094204bcfa999cc2ffca',
            'ubuntu:aarch64:20.04'=> '33785f5ad110084da71d569727fb13f19b7da73754a86d4ec02c9fa9be67de46702092d51fd5ac3da6d1c722b998c19851a19f332aa2eb05aa922ef53bcb1c5a',

            'ubuntu:22.04'        => 'facf38965d6d889502cb0cb1d772448d8c28f0f729e73ce0553dc9c9798ed71fe801f9b01be37e9c41ecb6b917eb862a41fe44e6739dd51d89974b9e8e6a35dc',
            'ubuntu:aarch64:22.04'=> '75addb7ba13e60e7df2ddea0d66d30d9bc78941576819b705b2fe847d969b1ee01247b4d0d3dda2e20d7ccda633de44d2a94acfeadf0e09f50a89f1ea534c029',
        },
        'boost_1_81_0'          => {
            'ubuntu:24.04' => '3b624a8827e802bd8e188ca8f580ddea17ae824cd974f8d031cd680c86cf983efbd801d20ef7da68ed40b946d6c0108dba0d3d52fd73a50294f0beeef1c177f3',
            'ubuntu:aarch64:24.04' =>  '17b94f04c84054c4ffabf7c03fed0a6ba53f6f347cd95af2b997b6a70540a104c6d7c3b5cf4d5fa16a768e41e49e2a5acfc4c184e572a2da3dae0456912c5cd5',
            'centos:7'            => '',

            'centos:8'            => '3ec346504035a28b9a6790a765ad8fab31a9896d762c77350e9368bd14a85b1ef1f9ad348ff46811802c1c2c49e43414eec7682b6f559684733b03f7a30251e8',
            'centos:aarch64:8'    => '3664fb3548461e3b4a6112d2dad2b5da44cf7567232858c45ac99e8f574d4132847f3864e96955f6a384e2d7dc7bc88d3317e29c939a8218347289cc1876bc01',

            'centos:9'            => '5592811c8e30a09ece9bc389059bdc6ac56c30f48d6da8dc641cbf69b90ab28da55c861f5767096ed8a4382b3765c50c569a7988f658085d952fdebf404a86a5',
            'centos:aarch64:9'    => '70f82e80c4df166d89318d9fc38829f350ed48edf1d2fe27764422f15d37263036ab720dab0d096af2879dbff28b02c6105be3148ef8e0721030ab4f370abc6d',

            'debian:10'           => '',

            'debian:11'           => '538e01d4a06c1a62a4e94fb29b0981cdb57b75a418814a5d682bdf81cbede43864461fd5cbe2d03805b5fe783b64ed3095eeda5171bad277782846b56f8b8c55',
            'debian:aarch64:11'   => '7a1bde83552b725b073d58976937395efe684e9a13b89afccdb55ed25b0c65548f8102a50db268998eb07a3aab3fdce7180e483f57f60417f7a8ca03ad818a69',

            'debian:12' => '0211858aef88a52d45cc2cc41be7d790eb54fd805c9ab4cde21fca65b997b4c949d21b771880bcf583a0d7846812a3ed097f27b66a22b30607348d860adb9734',
            'debian:aarch64:12' => '456e377f4ea67d4d0eef464cc86d0e94967d4616e7349455d4d30236380aa1338a87eeb397dda0b9e098a4bd42bc71bd1701e29f0d0d69d6399917b9339e7888',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '303b773330c342d6ed3a5e26bb351a0b174ffb70a9f8344740ff5a1c4f84f1bc0ae845a3101a802eda27846fc41ff4085f76222ca85f70acac92c10a75b3070c',
            'ubuntu:aarch64:20.04'=> '33b860b8836b7333e3acc1bed61fddb0de354292c1448884af903bffd1e13b633ed397110cec17e3f706c525f59073b69505e8e27f8e169c2c47fb84195e10b1',

            'ubuntu:22.04'        => 'eaacfcb8f1b297a3381152ab7f5fc2e97008b118529cc3fdc8d28da4a0529354131b1eb2d4eee751c8403bfde58921e9603073578c76890f43780346823a7a37',
            'ubuntu:aarch64:22.04'=> '9aa5ab7d6750a5657cf9f94fde6878a601c9a4559283d5860b19c59c51ec820d9c525adbdcdacb9fbf15b6c9db44ae37082d6a94e72a2365b0253b19993b960d',
        },
        'capnproto_0_8_0'       => {
            'ubuntu:24.04' => 'cdbcdcf1963c0e741aa5dfbaef7aa14a22ae5db85925e06557ef22696ab731d7ad0ad4318aa68f07c8d2fcdfebea7c9f8d3e65697228f86ddaa0037ff0489a1d',
            'ubuntu:aarch64:24.04'=> '961b68b86a1a7e194b5890bef50b1ce11e52c6ed64052d5036068c8e5117001a01d5906b554a5f2e4ac5794e32d009d8d7634fe0ec0a7fbc88495a6b2e2b7de6',
            'centos:7'            => '',

            'centos:8'            => 'b6a908d8f4a96d924082a2cb6de99adfb3f36b9bda7ccc3f0a3c35144b362e760c76645e46356da0968cda05ec058384666a3e118e8f680246c2cd3ef5fc9815',
            'centos:aarch64:8'    => 'dbee7cd936750f11dcf040de426dec444003a211bc535c7c05686fc3e4ade65d6f27831caf735d196e9f57b5edc74e1dacfbb12130e31be20a23d632f8e10a93',

            'centos:9'            => '5e21ad45e7c32cc6fa4fbd40638be305169e32cb7e793a63c4c9d5256e701062e5ee1b29d6d6d91943e544009e9fcc89e86c982545ce42e4a0db430ae8c21b4d',
            'centos:aarch64:9'    => '3fd7720f5e556ace602b746f4e3ce9571d07c7e1691241ecea64cadcb94da45158b4334ba8210cee7f43d59c1e17399fdccab5ba0c8ce1bdb5251b1ba91ffc26',

            'debian:10'           => '',

            'debian:11'           => '2d516e3cd55045fb585f06575d1feb9b982fb32162da35f67258c3c27a27fb369231840c5b06f9dd51b1db4053e288239a5aa37cddbf48dcd37caeaa4f11fdce', 
            'debian:aarch64:11'   => 'df3898df1b35c67542a0a35fd48c76ddc1fb1594415fa2f70f9c9f825a306f7e3972f207c3921c954fb6d5524ebe4f5fb9f790bae41a01dec39b5f38ff69c4fd',

            'debian:12' => 'aeb18b4c5e40c005c8fc05a8527e423e83b7b89fade0f973e8dd0aca8d4c5fdac021d4ec2f382ee24f330ccee7b40387b3da588235e1230fe3af4e521746257f',
            'debian:aarch64:12' => '330d6e98f9b76f7eb8db2fbd4a79b374dbd69b703920a06bfc888d0c899acb7b02c730353d1d3a652a5a2af280d1f35dce2cb79c501081bd729bc9dd038fd81f',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => 'a9504ab13c430899d716123d8ba87744ef39b80ad5e563228b549112ccec03617fdf5bba667b913abed6d17888b7e6d7131d15f7bb0e5e990115d005dc016e15',
            'ubuntu:aarch64:20.04'=> '4b48295a103365f3a8aef20ab96d3a58db73f60695f299eae2900efc6780086e38341b9dff50e6d695aa45a62dce44a892531ad5ee7b8c324706cc9957b4746c',

            'ubuntu:22.04'        => 'fe8e8b9e954f6555a852e3ea6e15293d1ec57ad6117d23e26fe20db1ec892d3fe71b8d647f7bd0c8070175dd77f9a29ecb8500f52358f4441ca86ed0c8340fa2',
            'ubuntu:aarch64:22.04'=> 'd5bece9e1667139b63f0f411fa599faff9e3d57cf17aeb76302d48148efcfa04e6979b1128affbbd4e26527ea69c423312368bbfdc6284e619e9b202a80927b9',
        },
        'hiredis_0_14'          => {
            'ubuntu:24.04' => '995a416f5574e2c9519b81decaa9219f82b8e3761920740e432eb3ae373261bb88a74a8bb8c9146714080124f272eb3939e968b8807cf7d9e489089ee04c9e4d',

            'ubuntu:aarch64:24.04'=>'274638182dadfb512715c66f00bde2c0ad9d08d438968448c59d6e11558e89c47fe62bc1e7fe92ed403a8eeeab0723177e0b3f160238fdf66d4eff785b57a177',
            'centos:7'            => '',

            'centos:8'            => '305d18768ab72db6ea15633abfb1d06b04af07f2cc7b2f68ee8c607b43f08f0c0e102b748fef1800ec319dafef67d64fb4e2690d3a8a1fd462e5c17caf65af25',
            'centos:aarch64:8'    => 'bf43c36f807462179a2489bf062f4d8676e1d596a72d39456f7634e9af0b740c7cb602f649ad61271ff4a90dad175a46080e017b27fe2762f120f10dab1803c6',

            'centos:9'            => '9d7fab589fbcfbcd97f654975d81a7ff5e84c7015caa7606de2198ca6bd84cf845cd18c13094238c562282afacfaa75315a28ae802cba03a8a0f5b113def2aee',
            'centos:aarch64:9'    => '965b31ee142bc4f2041da1cf906a0a65e226c5bd5edf9ed46bd7659a73c2fe3cd3cd85c8c17e96ce6205045661be50421cf373deee74a33108ecd2d0b4ab44db',

            'debian:10'           => '',

            'debian:11'           => '7fff54a781812d3f4987b7aa9d594d0058913693947e3766f97e01f8e87949d887b8abfcb77afe165231c186ff043b1db928ff8ed5c81f372e6324d183f8882d', 
            'debian:aarch64:11'   => 'e7ee645247e4d083a8dd67f2a0486efe4ad08cb407a3aa0871ebd6bb764a65d96ce8172db07880e69572ca815e22528edb4be6017a8dcf7dfca963924eee74ac',

            'debian:12' => '9eb69a0e0a0a49a1a4e4cbc35570ee2571b79fce3e017eb7c1457aa55262b79224ffb863d12d2b277c1682c1558f5f5d5e36fa9952e456b5c7c2c676463ef01d',
            'debian:aarch64:12' => 'd8cd81722f960a0d3f661badbcc81f6589c10707b69dcef5f1c49626f1b19187518053516012e647bf9d635691ee6643b12986ddb49a23727868ca96cdb45d02',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '772321b446ce2c434b8e1615b9b7d49ea45d3c5873ebd159cfd43efab4893eee7d5998fc1842be55c45b01d661048a918e96f20ce52c8204d74caf92756f1f57',
            'ubuntu:aarch64:20.04'=> '56299584992d68c5befb4e19a566381ed3dd6c35a043b6b37ed1c0cb4163dcbbab14c1c84d34b4d1e1c0d509831cba17988f33738e56e2543f245b7cb4b3a56a',

            'ubuntu:22.04'        => 'ef89abdeb7ff8d24ceac06381a3045db8e47701a8af4b4309ec05214048e824a488b6ba3aa884156d969279960f63a8ded5f7868529792421a2f09a535778855',
            'ubuntu:aarch64:22.04'=> '2b5abc970fa32c1987d1855f4e3f7688fe8075073c3986153abe6b85693b03deda73f3545788893d3bcdd814db26ca9ce6408a5b38bd1c557adba78ce3947266',
        },
        'mongo_c_driver_1_23_0' => {
            'ubuntu:24.04' => '3197c4a62be093bc5dc0a6ed89f689d0e39b639b83cad0414ca7e63f344ef66915e75dbd1aa0424dd2efcd55a4a7bc34e4c2bbb04b2475da482b5fe18d931e69',

            'ubuntu:aarch64:24.04'=> '2d7775ebf01a33574df3fed3aefd83d01f7f3c2dd55b92c795c91be289cdcc5a64fa21983eda0cca561091f6e7884ae735d18dcce7a52336a1bc3b4c5bd82f63',
            'centos:7'            => '',

            'centos:8'            => '4299b3c984c0167716f6492d2b1f46cf41079a40e932682bca7aa0deb7a298773e71efda235ecef493288fd1ed4e22b24ce463c8a7140da4d399321d1c1b7a41',
            'centos:aarch64:8'    => '462e8fd9c4d0326eac30f39d891d5f90f6e0da28ccc37280cf57ed2051b974260a8842ed3b4840666c0c13609e0a9ebdc52724261f92c6b8887b95fc4e1a3450',

            'centos:9'            => '508a00ef80cfeb0056196c5b916a80ce5ea2dc01b549a2f58730c49a69d3218ba51460b3ce614611b013ad4c1ea8acdd1696c3f45d37db58e997cf33c241f8c3',
            'centos:aarch64:9'    => '52b6ecdac040853e798f571912c6db490f4f1c6d7e22cdddc8af6200cdc5272029a8c26d0b01742081648b6154f00f2ae7d0e44346ae011f398ad130ce0e1944',

            'debian:10'           => '',
            'debian:11'           => 'b1c1e3285d4bc8ce3bfc7ffe2e28e51435ab9b9012cd74be4a01f63a0879b72f809f1b1d99a2572a689da474bfce373c08778c43c25ebeedc2989419500fad8d', 
            'debian:aarch64:11'   => '78b061e3f139dab6830cd9ef2bdc856de01ade01e0e0d73b656bc55ec2cd5c7ef0df3c530cbab6acc78fe2ea11f3ef7d229e64eb46d6a80335ff1e4558922a81',

            'debian:12' => '25063237a3144ac57a8a56196a121eacb164c46e512a7ccf155d6fa461e639ba192311a1cc09381137c985dae9be419908f1072b9688fdff62de2b0ea1d1442d',
            'debian:aarch64:12' => '57082c3d7c17a3ad50046fac73d9d4dc2d9024aa32ce8f7342b44999b57971193f144d8c9330e70157c147aecdd950c1bd7001d818e558a0167ed7a1a045ab8f',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => 'f588fa2153c5fd53665280b88dcbb49e1d22b68774122b49cc4539e5d85ca899372205bd6ce2a2716fe6d24f63ad7b496edce10012f50eb4244cb5b5b4301e37',
            'ubuntu:aarch64:20.04'=> '6354cc7abee82f223cf2dbca2f654737caac91cb31f74417d1205291d805af9c8797e7e4a3f922b72572d95d5ef76d0eb3908c359060e5817c98425fabeb6b80',

            'ubuntu:22.04'        => '9e5c4bfb2c06618f8a816f7e4e1a194171f4a049c4ae5cbf6acb960864f5d3c70b43d8cfac035c257e548d51aac5337c1e7d9600b5ae68012e0a41ae64ed1e3d',
            'ubuntu:aarch64:22.04'=> '09ac4daa9edd9a8bb1b2717249cc4a7e73d1e0ca7f527effba0524ffae4473b7d19699aaad64dcbe5a29abfdb874a6666e9fbf7fba1de653bd1f811defec2eec',
        },
        're2_2022_12_01'        => {
            'ubuntu:24.04' => 'ffe4c7410e5ba8b122396c6833e8ac270269471089af7ddc26acdcc3e86261a758ad835d20127e639ee329945cab2665ffe2a77259fce8644fcae5eeff7ee27f',
            'ubuntu:aarch64:24.04'=> '630f46a6be91b6ea0a351c784e9f893e99ab3fed9fd54a24fa03e95876af15afa222d372916e5cd876bd01e40151db187f9612aa1659411d786e512fed9041a5',
            'centos:7'            => '',

            'centos:8'            => 'e2f756883a50e6a28a75b9f1fa5b983072e69ed07a39c63474697a44184f4a04e233cb5617aeef0df7b1417e9436c2e77a7c9e9882e2683875d3e1610188da65',
            'centos:aarch64:8'    => '72c742f8c204657825bfdbb7d08f3e0602b2338de335bd76ab90716c6be7e93a1dbf353a1b5261641a0e659071594d3ad6329deb100d60494d20e0c70c0a1d26',

            'centos:9'            => 'b79a900a7f8bac98ec641071f56da5be60159e9017c69daf0d1a55758d3ece21e4bb3fe2f574c3bbf52286747b23ebfd856c61fc64b4f201392397b900e39ce5',
            'centos:aarch64:9'    => '0197255d276e635e2317b7cbd86f8562fd4a5dd4cb6b81ef7c8149cea54ef452bb312baf7762876cfd584771cb1da31d7f17bd3369aac1e692d6b7dc520b2f20',

            'debian:10'           => '',

            'debian:11'           => '5182ea7f2a0d6e57f21ce1f80f67b82eff8157026c2db820635a4e2a6360733c4a11c6ff4c884f1293709f41b84b873edb4893c7ba46bf84ad540e9273adaff9', 
            'debian:aarch64:11'   => '812f7636c2c4ed52f52f348a6b69215bcbde9a1e7f0298a79a013f5464195c9045012de35333508b199de465a503d5bc99a93a1d431051f37734ddc7705db42e',

            'debian:12' => '9fe3251eb91a1a1c5f2b5074ca34979e0490f0fde304fb1fc18f8d032565572cc68dd611ac65f76352f7b453eda21fd2c75610cfefdb06147ee81f2ac4ddc097',
            'debian:aarch64:12' => '32cea7c38ba231d0c615484c9e7f4c11fbaca3ef4dc9031ccdb76ccc970a37a95f4c84c94279496d044c7f865dcc71b3d97fbf739600935c196fdc4094e6d700',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => 'c6c90db00f9f38b7607baf0d64f22940a26ddf61572b64e54bec83a67a9ebf7bb210c002a7cd96b92ec8155aa0c89558bcc0d2716775ce5595cb46bf80780e76',
            'ubuntu:aarch64:20.04'=> 'f51f29654f1a1b23b4cd733111b07a7cbb4aa3526c4cb0de9b4cfce5099eab099afd250ab95e912fa1d1124621f6719fc84da65454412f6e3b7501d2e0ca3a18',

            'ubuntu:22.04'        => '9ae3f42af6dabb5452a9774586c9d44cd0e04cf812977dd9198f69d840e592e8a00abf267a07fb13bf30f597e5758e557137459e5d181b2daff9c6ce4f088847',
            'ubuntu:aarch64:22.04'=> '6a39c5e915b374e20b2ba482c4072b79d1b298de6c3d7c6690c65b99d6a6a3831bc53b13e2a04e7a60f0ff78585355c1980e25b7bdcb03aa46a64d1d4ad18f00',
        },
        'abseil_2024_01_16'     => {
            'centos:7'            => '',

            'centos:8'            => '3daef66123551be2c51d51ec2e58483652dddf3281d1b349f15ec90653b6a8a36599f585aaf821d492c83fe186c3c2ee9348643d8d3c9af208eb9ef9e163151b',
            'centos:aarch64:8'    => 'f5eb87d1dd044edce37332fc079b963015f6b3d5918f0fb9bcb77963e6be201482dbfe35d279310ee0cdeca9618666c20cb5a769ae21fbefc5d8ee2d562e0a69',

            'centos:9'            => '5764478dea082feb72b9b70a0c79c5c394821045c1451d9db7cc1a476ad8e5ca78cd254f3804bba9b4007818a3b14de9d8e030122c8d8359deadb99ec2eb4514',
            'centos:aarch64:9'    => '1aa06ed751b32233e39f2a43ca5a41c4555a68c1e904d52ed556a874c1b4ad8e0019fe5b3def106ca94aaea9f28360c49ddca04d5b37490dabc2b8bcb7fa22b8',

            'debian:10'           => '',

            'debian:11'           => '1601b4d63494ac4b3cc22507b0b597240a6880e605a6dab913bd96e7d0f99c31d4d3ecfed9c528f89f9c1ed9bdf509fe131219f9dd73812bc1cd3e64cc7375a6',
            'debian:aarch64:11'   => '5a4dc29115bb182ac84ed315851b0e7de926044d731a38a08ed1e0eca6a8bab7dcb310764ab61ef164469f02bef2293d7e6a07dcc8eb70eb418041d91b4f00f7',

            'debian:12' => 'abd9f454f4aec40cb5ca3ed4e1f3de7616c9f96cb55fd738bbcc5da8ddcfbbfdfbbc379d8788205d7265dc0284417de6d9c53a2fd0136cf35587bb02dcef4c3d',
            'debian:aarch64:12' => '26cb6d14cfd595addb72b2355507f72b355f1f1aa4ad64a7f4a742a3697eaf56086275d310567ac31ca1d85ea2985f25045d7381a53ab75ca66d622860156a69',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '6eda5ca283c916578d7ac9b307b3b67f92f8fced478b65b347b00c67c58253084b9362c9690fe639e46c3e600e2e8fd27515a64b3147e76379cdebc48a877d5b',
            'ubuntu:aarch64:20.04'=> 'f725492364de885716c6264431d79153aad160e21bb78dc15c0b0b19914402b44bf2fcbad95d26a997ee8b5f13d26cad5a8d984b64ce1249129d8d96c5c6b8ec',

            'ubuntu:22.04'        => '41be0b0de158fcd053d6d9f5d6c01dd97126049ce2935a002a7473d07c99d640fbc7f3db4895394c99067e41fab1737a2b1d6e4ab0ddf389109d267e039bab0d',
            'ubuntu:aarch64:22.04'=> '84d318542e11b5fea2d90dd69a56d35d0a21d275452620fd4b7235cb27f8efcf2228f9707b23d37c0a023928c01ecc6a10b1b84dcbda9f7bd70e333cce93fd8e',

            'ubuntu:24.04'        => '311439b2a519950cecb9a39df9a4488b4740cdddc4312189e27f030e20a1053fa1fdea3d90741ca8ce424dac67e50bf16d530ed1311c6e54d9860d90d69ee583',
            'ubuntu:aarch64:24.04'=> '92e92c084f8b78fc3f5bef69ab41d05fad210b4da1fbc23715d30bc050e9aa137c8ce31fc9335f4832cffbaafeb3d01be8764840a60854d5ed74f684fc458af0',
        },
        'zlib_1_3_1' => {
            'centos:7'            => '',

            'centos:8'            => '78eaf8c7d6397138ae32d627805bf5aaf2db50e15717280ae72a7526f10d9d9e50ff190dea2862e8dfff97b82d43b5331b5ef4b31ae388ceceaf67e13a922404',
            'centos:aarch64:8'    => '07090e7e2b5d69066f54d8d9d2709e0cac067a0d40b16552825fb1ad29daac59cdeba1a9e6656f60104653680267ff2f4931a1b6bf2a9fe1bb50004e1f93790b',

            'centos:9'            => '4a2fef2ea74be0a2904bd33b852ff6cac6dc52c9cb0038fbd2bf278ec4cf04dfb5daff12866c0f1080293cbba33621175079d4e4eeebd79e8a389738573e1d46',
            'centos:aarch64:9'    => '63aea2a672f9d0fcd90b9007540338910bfffec0d163d29e62ed4f973097478f4f99837ebe475f915032c1b720252d49f11d8a5dbab0ae8881f24973af681fb6',

            'debian:10'           => '',

            'debian:11'           => 'e587770657b01821e9b4acf9a4eb1d886d7fbeb77346964ff2f940714f2abacc4a15200fe0bf21f15eca84fc683eff3ff8dbcb53322bd2a1ab058800fa26307c',
            'debian:aarch64:11'   => '60b291056c4159ebf339b7362e7983b2d126ffa4c8d45cd33cb40b1e25ac8cfbbdb932e618a5869e59644b933e98ebdb8f1394c8b8b6a68d34c4bf1d984ba6d3',

            'debian:12' => 'aa102857977a711d165c004035f335cbd1d4554f4940978f21efe058cff04a8e498f04f7ac654606e8b350cc83e742103d6822a72f24ed7cf925cff3fb216095',
            'debian:aarch64:12' => '5b1ddd12a19d20db150605a323d4b83e64c3d916da4688b5d031dfc658a16ef4718d7473c68f5837392b6bd6addad3108b5f05847c432e37ed656077ebfe96e2',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '63d7441586697cafde850b8562e6f712cee3f901e77fd0272167687171382e734669ded552341c9e23795c17cf39935385ea16dc6197f261663cbde92ac2c7c7',
            'ubuntu:aarch64:20.04'=> 'e5dcd5a7dc900b762c05b28e440008cb04cc534fdd01e3afcd5e53a6c3062c9f806ae728a2609418a9a9c11b9501946a3d5cca341d481c25c1470a03d495099e',

            'ubuntu:22.04'        => '57fb366370035942f645ac3f413f76eab5734cbb1e44c0f469ac056d86657b1505ae497faab6df1ccdca77ff1017c89655e71385b71acd5dc5ebbbc26fb2b257',
            'ubuntu:aarch64:22.04'=> '51c48451de06246bc0e977ee1a1e306f35954b8bbc26f47a202858896fcdd4df4c2c9a774e8add8729e3e792b25017ee0dcab75a011aa9de8adee7854dd33c6e',

            'ubuntu:24.04' => '558afd98e2561986582483aae40a35feabfb860bba68f6d5705d5ec26f3230061e9af4ef6db2137dc06a01c8aaad3f548b6b13d6cbc918e24152b3120ece8a6e',
            'ubuntu:aarch64:24.04'=> '1e4dcf0b9a5a50ea92ebc3729a66a1bcb20149228dfcd83ce9c5f56119b9e8db78aa284ed490ec032e56ddf83322fd94587239e9a87e60a87b0cce12cdb75ce1',
        },
        'cares_1_18_1'          => {
            'centos:7'            => '',

            'centos:8'            => '0a8e7beaabd5afc328455149042a5dd45fb6246b694e96a60ae35e2b74df48ed21566384f22785e534f26bf309cae15357eafac4b817871e75393b8a0adb7ea5',
            'centos:aarch64:8'    => 'bb766e940490a9c98668e372f3f5714b6ed35a966ae2bbd75c23f571ce2456ed38954ee583e533218dcb7665e86267618b28c39d84bd92185e282f6a3eb9bb72',

            'centos:9'            => '2709c947fea53c2a3aaf7730935dd31bc3956614f71acc57f365c6566ee0d6ecf6f9808a49bdd5ac074e5ae267e5148f574388cfb4bacc4e6da9e1ddd0ee7e29',
            'centos:aarch64:9'    => '3f0c7faa10feabe257ddee1f769d58832429e6db05ffbc6ab1a85f84cc1abe8756bad85aec71d5bd91cfc6ba3ff69e3c7068c471ada2f03ed639be7c9a2f63c2',

            'debian:10'           => '',

            'debian:11'           => 'd6080bf481bc67e621ef16b4e9edd0282ff10661bc8e94fa6bd6a20baff3541fe2ef584e38499a7cb9b62461c640f77b8737ad9e2af61a17ceec23a4fc739310', 
            'debian:aarch64:11'   => '7bddf6fe21cc1af66be126a875b8903f1f7301e20adae4d673188800320981893729599c06f14f20ad86dac859f867ca192e5161bd2e53ba9a7526b2ddb29d57',

            'debian:12' => '176d98c42891991e5b602d677232f26b7f36867e0a1a8e459bb8ccf487e9215d5983d98ccb03f84355ba772ce14f5ff7930afa6a25556bd4cd302db6bc49f9bb',
            'debian:aarch64:12' => '4cfe25474a9a44303856f49ff4b314f7afa5a760dfce7b8b1e2448341c7150ffa9f1885f983d4975b9604daeab63443f0e7a567c4e47d7ac9ab77eaf1171c806',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '647fe1510d389a34c34a1d035585c07d66612846a8f184d33fc2be859af5801c7ef3b398d138d3d47c3be898d3de6548be8eddf874123f8c87680a4ac25ee447',
            'ubuntu:aarch64:20.04'=> '0c2a01cfe0407be4dd93c7916da6ae50d99ef5aed783bb2c0ba3c9d4160435634affe8f8bc46f447a88e08b8a48f0dd4c269db79f19e09e55903f433367ae058',

            'ubuntu:22.04'        => '48d2e2d9a141b34688435d9bf8e6a1aa2132d0b247ed34da0fa9434d90fecb10a658b7e6dfb6113880c0bc72d80ec029729118510bb609d4b8394ccace2cee54',
            'ubuntu:aarch64:22.04'=> 'aaf0f2cf41111412dd1fb2fdaf6d33f84ac0b0ded51b9ddbfdc4701d288ebccf6e74de024dba8c129745538730acf0064b475be1acb89bcfac252cfa7283e5a9',
            'ubuntu:24.04' => 'a0d169c14109f73fde40592526c2cdce6b3dc6c73d9a2bccf7d44d0493b1c9563267ef796281c16cb5b404125f2c080f572444e37ed9c8a96a94e8b2ea67ba71',
            'ubuntu:aarch64:24.04'=> '57cbf7bd01ebaabe322b3b4c7756fa1c4985c1a66deed856ec9c98224017c7e0ebfefae2f94a3164f4927db7cbf15af115a3dd4a4693ed23b6993d358b55d220',
        },
        'protobuf_21_12'        => {
            'centos:7'            => '',

            'centos:8'            => '1eb322b6b57f2adfdb3bfa0ebfc1f6e9fbe489f067c40923735fdf74ac6f9b46a1367d730c4aa8ed45ab21817f12d1d69bf7840ef4993ada31be336c172107c6',
            'centos:aarch64:8'    => '7d22b4ab2c517909e769d15b3374be53730b61aa0a317ee956c4b40f86b74a604c18b04b26040163bd91a548a45b9a54fe75bbf103ba3a3a7783810875b0bdeb',

            'centos:9'            => '07a28a4050e935e78d11d3385ab59671599d38a055d24276c49aed2e379aa26f7f59e45fd0df6fce51657450bb241780b1048a8def259f9c3ca21556f82af468',
            'centos:aarch64:9'    => '2b3baea43b3aafe78b4fcd5fc86c726b4015d8645c8d36756b541ee5200659f47f3688e8b9a75524c0715236276046f5e0c4577762bfb5c9ee5c7b6667a4f8c5',

            'debian:10'           => '',

            'debian:11'           => '2f4339f468450660e0077ef05e51712445f36a084525188a47d282f195fe043a504a1939601f743eb2c6f1163d87090444f729fc774f53ebec91995f92059718', 
            'debian:aarch64:11'   => 'd3c57529d6ef80f2abbced273fb83cb84a73dd8b3c3695de49028b8827b9c7e7ca7be70ed7f83fd7ca56b17988777030b916c71601cc555a8a5439df3a55da0a',

            'debian:12' => 'c19510a1cbcd2e8b5946fdc5c7b872bdfd41d2d6301900c0701a37fac6f2f640f956b0e30aa1b0fd3c5c3fe5d3c38ce46ad8a5deb8209d0324cf41b202b7b8d5',
            'debian:aarch64:12' => '20b576aeb46e3867aa0027d7c4876485ab16b34f8909c4b6e9a01aaf13f9905c4baf2a9e05edf3a0ee28660e7ea5909dae37d7671f06d1b15ebd48532057acde',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '64e318160f0702e693e943bf40d5463dfb1437e674f0b269fcb63ddf93e31fca1fa4726c8bbc0dc326c357a01512dc1716252e5c1906ab80b114bf0d5819e584',
            'ubuntu:aarch64:20.04'=> '9f4c3fcbc67d437edbcd306101944109288c5059f21e8c9bebe9ada5dc92589d32957fc4ab446d4fbf223e2aabcf7c6bf2a28f4c8af935fe026d78061445705d',

            'ubuntu:22.04'        => '2133ac4c38353b6bdd46e47e099c123717d83f547315fcfec4097dca7c6ac4e834c9391753024c0782682221f696d8c95b619a0042a60597926da18f1d287801',
            'ubuntu:aarch64:22.04'=> 'e27af607072cf237a368da3831e2176aed3690a316cb45ac4beb5c92bcd08048c723050cfad8894041be295839285f552fa4eb3ccbe6d8e3198bd412e9b27c4e',
            'ubuntu:24.04' => '17672a86fcf504ec7078635d9753bdfc16b7498a239f46171465dbb3af0e4eb0ad3fbdafb5b122c6966b9435b4a4e629a29555553d2ef9be2c5bfcb2e30804c3',
            'ubuntu:aarch64:24.04'=> '8d3fb1bef4bf219ced15021ac5d717911160a68f332210daf3d57ffc65175f4ac860b20b9547b80d83cae7f100dd7737160795c8fd4bd92e798c97b0f47ec6c5',
        },
        'grpc_1_49_2'           => {
            'centos:7'            => '',

            'centos:8'            => '0485da74ab2159b9207c3b2e3c1fd8165add53399ad59ef4a5efff2711738bdac9a7c9c2c08eb45c0d062fac47fbe76db6a5b80c9068c69ae2f5eb86d4a2cf28',
            'centos:aarch64:8'    => 'd682b04e408a8b6760f7d500d40803439f4246d40fa52b050016d9972678e6dd6cf111b9751e61a9cb0cb2cbe42278e949bd6c8cb0aa1ec70ece569b7922ab33',

            'centos:9'            => 'c7d9a3b8958c83555b90fc70a808a1f0c071264b74650580573595f9e70aaa9ad872f6b4c2136c2736b31f3de2c486cbd135fa465149b52853587151d87a7eb6',
            'centos:aarch64:9'    => '3456fcf1e036808bb62e79c45b65ee3f84133aaee86d4839a161c6c6ae4f57a91d5c94720d157f3be17d49f22de912388f705d27a98dcf438f2fa585c5297191',

            'debian:10'           => '',

            'debian:11'           => '414edab645d347cb9a8ad6cadfd504da366a1413a6784e2b03ea3c285aa717188237f25c9aaf0340de074e2c0473ed473407af1c2154f588029dcec6c6b66685',
            'debian:aarch64:11'   => '0cf5dd40bf3e4916a67d0a1511c456b4543f077d4735021834f1baf9ae2ad98221b8beb4c14f5eb9dba0a00ffd84cdf81758115c1c850b9c3c128b37a598c8ad',

            'debian:12' => 'aa6c0c42b5a869917f37c8b48861c73f093bc193eb95fe74fdba9738ebbc8a067f956c8f8bea3ed41d302102ee0b076770ffc8f09fcada5552772b589d7b17eb',
            'debian:aarch64:12' => '1e9332487a6565a9a2189371658d0bdf31c7dfb4f2c9182fefd467bc20897411b52533a861688371b65d874e80b628484b1177bede66fb8e5d54649b38164964',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '044ad1c97b9e1a1bcee8f1e55ab3e0bc8629322a3972d2e4228d74e1b9c2570f6edd216191e85cb2b49d944f4f48f9306416d219563f1bec30282030dc03031e',
            'ubuntu:aarch64:20.04'=> '6c6223a11c526fc189b444600b163254014ad3a45dfd152d8e3315f81f99895deb441172ef878ef4892469a7d0f9900ce77bdbef8427ee5494aa936e8b82c3b3',

            'ubuntu:22.04'        => 'd756fcbe5a5b46ca4a0aa575fdf4ab5d3dcd6d71b65de1029d176ef79d85d41e3c3d866cd3f7dc8ef909c9973b39c8b23d4227f56062037bc9fe46679e99f0aa',
            'ubuntu:aarch64:22.04'=> '8657bbc3f217bcd78c5bbf77860a077e9c5d91e54afede5ef444f90b3483502305be3426dbb1bcdf41d56255c51cec8145b90f9763a973e01655303b77afba11',
            'ubuntu:24.04' => '9f7a539d7f12f8ff73cd6dbff78d445b830abf844bd7a7a90e513240f6c15d514548228781a7c9fb94554b9ef9ca9bd29163d5b341644c8d5bfba7b490d9eebf',
            'ubuntu:aarch64:24.04'=> '822da657a81828de97ee7d479daf6ebcae574b8b432552890e0891591f9c59a6a43a3af416ac9c25f26677832cee4d72e5b0e5011fc52dc0b92696d73f607e22',
        },
        'elfutils_0_186'        => {
            'centos:7'            => '',

            'centos:8'            => 'cb087e29ff70ec8b650ab9d52f731fcd34fda99e3dc8d6fa2160e88e0ff5b539c8b5dbfd3254e5a5cfbfc51e6687bb13bbeda99fd02799ea5ca1d696cbaa52e8',
            'centos:aarch64:8'    => 'f396ba61bbe58ff950201fafa09594514a422c624c174c0b7a30d045475c73bf11f38448d93121d1a5196ce1f495b0b6290fd4825b736ea194163cd02ea566c7',

            'centos:9'            => '5516d5256dbc104c662575ecbc42c741ca4dcb4f44fd1c5a7347d848c1b74ee35266a1babe8ea61eef930562e8e4a9e05eaa6f03b5d47f4632d1dbcca8fc39f7',
            'centos:aarch64:9'    => '8998dd04e3376510e7e8998fd2adadbc42a9869777a2af9596da9f4acfbb5de8f7a03a0a39e398dcacf76ab2fe13994f48990e8fabaa7afb4b01c762c4ba10b8',

            'debian:10'           => '',

            'debian:11'           => '34bc0b4945ea427bce684849531ce7b401b06a69c1a9f394e2304b3ddb101f2b4eb34ccaa6c897ad3d1393ddefbd3b9c6b6624e5d7ac4baeed0a62dc7c0d3f1f', 
            'debian:aarch64:11'   => '86d50db9f96f6389eddbc8b18cba762674c0b9eaf422d8f420d935fff6aa8b4c4aa677c28992d39dffdfd1266030e2753ca70b09761e39195980be8c2f085200',

            'debian:12' => '75f9a438ed40145b8084b1599c966e2fac5bef0bd1245e4a0ac3558fc1c14e695807f61607f0e16d79ef1f24ec394be8971f227396ea039ad30ed40c7768c8ca',
            'debian:aarch64:12' => '8f3634261882e4f3af73a63564dda6712ffa708f025d941b93d5cf8dcb97cfa5c5f8f283209e58b0b08d9f83bf67b0edfabc1d1116380645b1a4f480098bebae',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => 'e2fba1c8448065af1ede5e34b62919b8f61a12cc64e5d4fe6a8da98e59b8691f60fc19433b76dac8c1a6ec55f7c0723c080c6ed0148f267e44e158e9d7c21c8e',
            'ubuntu:aarch64:20.04'=> 'ec4b9af6ddd212a918b0f2b48c245be282d73b052cee94275f00ade0e6f11253abbc262cadfc46ca49433154c060d2a13a17b39ba1b90a491de387e958f17e6e',

            'ubuntu:22.04'        => '5edbb6a02725788ef405b0c5282cb1daf92f9e9315fa849ef6fd061e9de3254e78ba0c312cbd910d5c571d10120d21d4e9f3a1e3e6319fbfa48e5131dd4b52de',
            'ubuntu:aarch64:22.04'=> '20e947353dc1025b826f5b5d3a0c64957cb2f3a3a872737499c942817da4af45c90902935b13e26f675cd102bfde50463f0bd33934d7b918c0832c934dcdc8dd',
            'ubuntu:24.04' => '8f586b8682a7fbd1b3e79d37a496fe7a04015b1bb26e6c53622a7a8f2f3a32eb79bc4f9184fe9fceaada164cd99fca7a6059f4f8b3297eef807c818a93b856be',
            'ubuntu:aarch64:24.04'=> '148fd04ad44ee2db493a60baa058829ba39287ca5868451c91620982084c3393f44646141caf9118e115d7113f5d59d88ecca5cb448947c84fd244260b51d02b',
        },
        'bpf_1_0_1'             => {
            'centos:7'            => '',

            'centos:8'            => '5e52342a4d0d5e9a04aa760184d22ebbe87cb4adfeb708fd79539916f6710ec5da96ec954807e592d91cd08b9cde25dcb7192f76e3ada4198709b20414bc027c',
            'centos:aarch64:8'    => '0ccf0cf5fe066a582d8d8aab32f9c9223504796c40c27f59034016495d7800bf4399508f7841b9420322e491c077540d60c88869e267af00675cb061ece269ef',

            'centos:9'            => 'e4881932ad7dc7bd64dcc45de3a56127b0a537da9b526d62e4144f98a08497f85dabde3a9189b4cb0528d4af96f2973f591a7cf4e96e28067b538c616feb7493',
            'centos:aarch64:9'    => 'be86b44c6ae510e2dd74b7083a349ac87b3ba31da93a6363144bc30ffa01093015ee02e6cb205931d33e847a8d9016f1ed00fe08e61e85bb70fc8217f8ce8620',

            'debian:10'           => '',

            'debian:11'           => '6db3a29c000690872f5ab7eda81afdda2da9bacfb25e3d60281276b69b67c5d67b6bc34aa41ad54bbadbc8188d778b3c9e952df58eeaeca8593ef896eef61ab5',
            'debian:aarch64:11'   => 'e41b27fe271f751a369b9e78d51f82877f6f20ded797eb8f9223c811c49eb93ca434ad1584e21e073b44067a13e6344861fb26bdecb30679d10b0fe2b73dec66',

            'debian:12' => '4252d2bf93ce1f4f1642b00d08e22a587145e6b1a475c5eca6461e82e88ac0409861be4049d400e4b22747598bca0af70de4217f236d8681fb8792ebafcdc5fe',
            'debian:aarch64:12' => '5153d4500b48acb4f3cdf97b709bb0793c56156fe890c8c90b8b5f1bea0804fd99951e9bfe0a7e8899afe8085d03b7260fd5940c178e711e537b4b84964cd4da',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '2c2777b4daa76dc1f4c78eaf86c3204cac2aa46a3985063b5cec3b28febc2653d58af84d9537c6bcf2344da91750c2f427ceebcc11e93ab5869f28f59347343c',
            'ubuntu:aarch64:20.04'=> '3e209563488f7b37d16036940606822b3b5c20ac4c611907ed94996c427ecbad5bf03ad5e75cfbe81fd38a0de0e30085dfb45e70d96394597b7886bfbad3c193',

            'ubuntu:22.04'        => 'cfae1e4ac98d5166e2bf76c8a61f4924a8920420a5455b8e2ee19f9fc5af9a0ffa08a87c24fb052faeccd55cf8f420fc29f699949100bd77649bc37e6c78ba61',
            'ubuntu:aarch64:22.04'=> '287496e78a0bcec93f84541cebfb1db85c70df45854354c50097dc00c34192299d87c1863263ab18000943c72bb87d65ee70c49759ae24a6b0082a0cf86bb081',
            'ubuntu:24.04' => '25d44d8146e673a17f4934b0cf727d45e72d49711cf02bab453e4cfe1cb0e36d14d510b98c4af684352ec5842cd05d3a972798ef48f342c4bba8c58bb202859f',
            'ubuntu:aarch64:24.04'=> '9f89bef6335e0aa0d6dc5cd3dc423023cb11614bdced91ac85862cd04e110f9ff3428be26c644bc10721435a0b580cc5747120f1f0457ed3f58bba5c7b56dbd8',
        },
        'rdkafka_1_7_0'           => {
            'centos:7'            => '',

            'centos:8'            => 'a380533fe1bcc38441e77bc74c4b7cb36f280dffcd396f4d7a59c9b8ff09e57f48af965728d1aca65313dc0ac9d0f429f74d74da5be4db37681a88074ad575b3',
            'centos:aarch64:8'    => '6e0bf24c6ce3b66b670eb93e7627979e32d774f89441990bcd3ede59fff04265206fe20072513465aa08a037db5a1aefde7c3d7b11c71692dd8a1f408123f12a',

            'centos:9'            => '5026f652579285a7ac629f10fd82761294ed9ca5f4d776ee57f1430d182453050a51d9cde3aabbd179fd060df4243a48aa5b76f20fc7c2b4a734698be1a6a922',
            'centos:aarch64:9'    => '76b02ea78af8d6997e0b14287e194467f3605e72f9188d7af7fb1145a1860684055bb313ff46948ede702ace9696b0aecdeb94c0e2adde8c5bd357570e73c3db',

            'debian:10'           => '',

            'debian:11'           => 'bb3c029d24ef5d9cd152de7cf95e61115c5d96319781cdc24f7fe57abd67ea84c0b09ff9ad4414d35aadd28a13afc39d93948b49c1f8730605b2b7f2dcc1c9d0', 
            'debian:aarch64:11'   => 'b26d21e2b8cfe1e37ec8bd463cc1ed6fd0fa94ddf62d0aa7faf9511c61c2fa0102d4a2629c1bee2cab778d4e87963d0c5997aef4debd5f6a65f48103d1c28180',

            'debian:12' => 'a36f72f96a0ad97912ff90f67dda939b7a093eadf3758d2a96e001f6105d43734ad35caab9199e46176e339fa6ab043b58f066347ee7199b054827ee9d0c20c5',
            'debian:aarch64:12' => '0e1ec1fd445b8145fc2acb93f00a258c42ecdc04c99bd76d6f2d4fabb83bc04a0fbce5d0a0687d3e1f7639ece1d77c38328505fce224d7cb95a5b1a9be703db6',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => '9965b15554acbcb2a9eca9fa6f293b35ac9762216707397337811aeb0c50bfb312f052f53d13f63996467b97537fc86a704c43f6ff8a6c855978879a19bf7e07',
            'ubuntu:aarch64:20.04'=> '51ac1ce1d5828639c61a36e68fe976123c0766407c962b7f8cf656aea4315c34b3a1c8f6e72a04558174656f80fba925c42dd179c2262f70dfc04b9c3b045498',

            'ubuntu:22.04'        => 'd208cb43dfd9887fda5e727f2abe9c56e9b689e1237c0185c68b0d58bb957d820479ccae7f49448fa2d789130beecf3309dd84488f94b3bd3f4351c60616897b',
            'ubuntu:aarch64:22.04'=> '3324013ab7f8753f7b401889c29ace796320bd975b53869280c1c45a6e46ac6af9cf9e51a928015e4a606137259c71770d5b992cc72aac6968a88eeef568a740',
            'ubuntu:24.04' => 'd3f24deb0e72c5158324af20654c816f157682b3a25c07c1dcb4a9d77742d306dfc1f8bf930b3b958346ab08f3ebd6a628f5364f3fca44bcc6c0d3f08e034b18',
            'ubuntu:aarch64:24.04'=> '41eb8bfa3a9d4cbfc430b4c13befce2f5c1ea57fe8d8354a5974d6647615779b8c9968e588a1172a9af180f5950945ccf6e688ff3dd54d8bccfd5bf6784c140f',
        },
        'clickhouse_2_3_0' => {
            'centos:7'             => '',
            'centos:8'             => '45c4dc5a18e4b3b3a335c7bd490f648e146f23e7ebb1ef5c407e7e2c70ac02581d362e050d38ec7fc21499ae380e72a83741df07ffdcf654728c6b123488ef1a',
            'centos:aarch64:8'     => '0e8e3c50dbbc7f0ae1ff751d8c5c1ba86d1fe688a858e670f18a3cb9a57ed71160a57dfe4c06ef8520457c83956f6c40fc15414e06ffa9142d480f6ca18f0541',
            'centos:9'             => '289b5bf8e470666fd0010f103e384b762dc412eaa49d28bddc9e335e41f802d33e1e7db3e1ad75328f6bf7ef9d860828f9e896dcfe18064f2503b7e7e01bf1a8',
            'centos:aarch64:9'     => '96a6f0d3cbcb80e86b81c2bb1f1136472227da1d89c03442b4504d53b5f5948060058805b6ad535fec12c1c23a9e9708bca970857285919f89f22eae3fe9c22e',
            'debian:10'            => '',
            'debian:11'            => '05135ef79479a0916391ad0ab89acc8998630aa925948d30d01fce222efe8f6c3cc0e3afa98f2b27618dbf7528bb314dde69a09264b0c3ea27930cfeb9748068',
            'debian:aarch64:11'    => 'b9eea1ea728bdbce977d82ef6125de98bb8706a98ad6c99fb4c092123ade08c0ad3cd482fd105afca8b07ee3f7bc13f555bdbd4e5580db36c19e6809aa6e2775',
            'debian:12'            => '945eb99a29075bcb68ebe362cdf2a173d3521f19a02d03d2df0863b565be1a6ea2659356394bc2f34eda11d0e8ab462f61816776a27639c09609a7919c66465a',
            'debian:aarch64:12'    => '515fb249540308929609d1cc6894a91a987f04fb300bc180a75d11d98647f37eecb92cd1225d888b4e6cd9b282c4f894cdd62efd35d67f595e2e5d838d84cfd7',
            'ubuntu:16.04'         => '',
            'ubuntu:18.04'         => '',
            'ubuntu:20.04'         => '7255146bd59e46cf3c395f079c93430224d37123cf5a336d94595b8c173a67e972afde819027b22b994924a927a83c83cb390db04de24a0fba26a966352a9ade',
            'ubuntu:aarch64:20.04' => 'f14ba78c71a787e90dd443835cb84f4e1890d4c52769f8b85fb47f8a21ea133fcee9b72d623ab3aac2823cd1b172b4ed2630db221dacc39ab07ce074d8af0175',
            'ubuntu:22.04'         => '111034012c03420235c9f114261640e9cf32059d67afb00386307744eacfa9fa8200ad4c6b54ac616882d4848eb702955a48199b2cbfc710a6813a251b561651',  
            'ubuntu:aarch64:22.04' => '842925eb29d5fe74822ae4f2cda9531df1e1b24a7e9d8f07381bfe18858d52da306e1a5c364271a5ec7d45f4b970a4a667cb879bef085b0496cfd2ec52fc85c6',
            'ubuntu:24.04' => 'f1b5c0ee61f0d44811bddd2098f220127cc7a25dffaed616b0b333d546658077594c8408d50995976ce67d1e657cab1fe489a72de8ef32bc00404412a6bb6ed5',
            'ubuntu:aarch64:24.04'=> '7af051bf8d9dc905e9d61589ab6a76470afb922b44c4a0b7a334e9ebcb4a315125a22412b680703c75e8ac9977fc4769f91d18570b3d38d41c0108353fb25052',
        },
        'cppkafka_0_3_1'          => {
            'centos:7'            => '',

            'centos:8'            => 'bd8aafb8eaa25fa5d3460dcd2bde9347d9f03e7cef5f85a92044f9b6996a53adc89f5dafbeef7518340f4d6b15a495ae4a976fc8c0f075a5b8ebc83479f7ee7f',
            'centos:aarch64:8'    => 'afae472a4f43ba9d5e22bcc4c22a9098063606c07c8ced8f7287fea072e8fef4681e9b1db606ef933c8674c1dd516b3ec45e23c0f9fad4aa97d162e33853f9be',

            'centos:9'            => '32479d8314c259e96870ebc2898b18126a3aa2c269d74d5a4e558e38d7e36129964f395fe096e14fc9c0db2ca1b22d4bf969d8367941ac24a55c4b469d220f7e',
            'centos:aarch64:9'    => '565c9f40cecc0de30634ed2d253f8ad867369231d75d22ea9bf08d7e025d641cda1573cffb13e521c8b144d9e161d75b316f774c7fdb24f7c177388e6245e97d',

            'debian:10'           => '',

            'debian:11'           => 'eef664c2d2ad57c35df39d05928ed99f0fd48aede8abf58183f219d62bae25c0868f1938ec453ed02354beb8d6686b48dd532d4b80474217e7fae4967eeda01d',
            'debian:aarch64:11'   => '68b3732d2bf073c4fbe42d6abe925ed64d7c02162b9094fde3b3e624a378cec44a2d210bf1eb60538c4eaa353ee828786c8d80b722f8e12175a5772b597bbc8f',

            'debian:12' => 'a4d0b719b9684648400a996c8ec70652beb19ae13121e4f8107afe11bf243ed4ce7f209a13b9b7d448f77949f4eae60e62c0bfc28a05863360211915fc9dfe04',
            'debian:aarch64:12' => '0cc61c124e62dd70f53680e4fb5ef8f8dad3b2648cd53a159174c90c09f309f2441933dbaaa42eec8726204cabf31de53b5feb3d87a8d1cb3342e1d42b955c7b',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => 'd133db75af256420975e47c3321d3cb86f79fd02433de7296a75e3d0ff37fddc18c4ec565a6d02f1f4223e12079656a334b897c0c2477820f882ba22222d3553',
            'ubuntu:aarch64:20.04'=> '524a821eadc94d6ca98b7f0f5fd6de36f355850c6baa4263c745fa50175273294aa7e012781b5dd7f2100935a2fecd8dde16bff7bd38d20c9285881f282ca3e7',

            'ubuntu:22.04'        => '22473feea931f9bb84dd212c0c2934e93aed86183798acab137f6045849a9eeff0834b7d2361d0d6a1bfe7d59bf09f15f57e8e974df43397f2534cd0468d5365', 
            'ubuntu:aarch64:22.04'=> '355dfb7e05e99f2776135118590a2459d3dafbdd5f06d048600709b6a0df58961f928156738741201e2e73880e950305cfb66ba49838cd1ba9268fa18e2ce6a0',
            'ubuntu:24.04' => '44e8dff39862672f9b3309ba9b3f1a93d9d4c404c64ed856b42a5785982c0123c4b229c1c86ae09ab5da648355a52c92490d62fa626f2d9331ac3ac088ece486',
            'ubuntu:aarch64:24.04'=> 'b523bd53f22609cddb00bff952e2bd5ac7cb58bbc0b34245d357ddd2c78218972f31770cb2372fd92dd913f8f16fba069cbb34fb40ac23463413b9223e377b7c',
        },
        'gobgp_3_12_0'          => {
            'centos:7'            => '',

            'centos:8'            => 'c25eaf82434917805a1717ddfe2d12b918a06a89c163881819fed7bb49eb1fcbb19068644ab527e4472131836f3ff8039c8d7d4c4f6986244a0098758af9c18b',
            'centos:aarch64:8'    => '8265213a82c9c880bd0071cca81855c2e3c7c770146122c9ccf6cae543f1c87b3fa370c581322b1d4062edb82fc7bacf9dd5a09c583189e54cf99a26caf01f5d',

            'centos:9'            => '7f172e7dc925cfac17d573bf45a419d89587dd607b1939be411fd35a7eeac56191b7ab51299c427f43ad50d87c1452257de0376569e78787d3d664d14747b837',
            'centos:aarch64:9'    => '70957360e7044e001bb9dcf39e486272daaf95483df2fd3c25c8b23a3788710f587188e6aec705927b834b99d2668b2226d56a1a024fcfd745876b7d1cecd8ae',

            'debian:10'           => '',

            'debian:11'           => 'c8088d96f1a9cb8d56c39572a2c53922f4b4f34ca73bfde43d8142d68db4765ad5cd77ea0f2222eeddf72b3dd626ef7ab301592ca8ec5b27acd697b534b31cee',
            'debian:aarch64:11'   => '6a5ff4369ad1f6f3a0ffb880ad0ae83610ccda6b76599ed9196ac550ca4a658500d6d0b44105d6d3801dbdf5a6c938eea4df43a6f3787ff586d26cb6eff6372a',

            'debian:12' => 'f83ffa24f40f8df184969f9208daaf62084005f41446efd7ec44a1d6e32a1dacac1b828b5cccb7ad1e9ca0d5cc96cdb5f7aee0c8046becf5970f4e6a24fe97fe',
            'debian:aarch64:12' => 'e38655bc288fe895413f239989edc2239bec45434aac861b31f1660099f29a459a8223d60068893d739b857f7cec95cdadba1984127ae5eee80799553cb8a558',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => 'bad361a34bb8759dac3c932d747a5ff89172db96b1c7d7fe17675fe5bb8a40290c1c7de2c972283730dec130bee4f9127192d684409996a30872fc986dc291f1',
            'ubuntu:aarch64:20.04'=> '6c46285ebf283523df17f01c0e02f82902be529f53aca52b871f9e047acdc285e0e9f3b8f83568fd9ecb9213d960b0d8cbc9714f96d0c5588cace303e6a11924',

            'ubuntu:22.04'        => 'f36bd758c818ac5392d32278757e28901407557b76efa00aeef9a05858d5c3429a6acef620b5344c22bedff2aff5406fc5b3e86ab714e7e92777a9dcd345b7fa',
            'ubuntu:aarch64:22.04'=> '550d9d8fd904a7e51cdd4c61702e0798a49f324f547c34a65790d837d7e8d3700c889aa4723ad340a403c082bb7c223662d8cc87a08e701440cc0b7156a20800',
            'ubuntu:24.04' => '22f843581f2295535635edfd715896579d5a719b92f24e030cebdc888645e42c575f3a15188da1781cb322d11b140cf06317f42db1494e50196d68b36bdddf8f',
            'ubuntu:aarch64:24.04'=> '31f3221d203dfe4be3b14be81cedc71b5e580a8b3e8c584ce4a66a22cfca6643d411dcaabe8c0cf9a151b3341e88a90d67a10f910840de957e8f3ad2dfc2f697',
        },
        # It's actually 1_1_4rc3 but we use only minor and major numbers
        'log4cpp_1_1_4'         => {
            'centos:7'            => '',

            'centos:8'            => 'f4dfa3c19f72035037ae56e47559b0679722ac9e2f5638d92d1fe4ccf9e6d4b007566edb0a3fa6bc1416b39d9f89323a82161eb2d8964d257f1cf7df66445cf5',
            'centos:aarch64:8'    => '061dc215067a6121a3142097d41c8ed8502d195e325ca541a67f8e3038404cb23120d8e2bf4b1d861930ee7a61c6163c983599267857235b4fed6c9bce355e27',

            'centos:9'            => 'cd507f7a57e376cba0ff4c2c390f6afe61d943d84c197fbf434fd2b695dbb5f7ddb8046bc90050c083f0cde6cc1056c8914815f2f1d0afc214693897c3aa53d3',
            'centos:aarch64:9'    => '92ca444b974894ebb9d019f1a971b5556ebc1197f334a90478d60740ef3acd7639bd3c6d8335c151ddd8ed283ac6ea01bcf2636828148cb8b8fb3352ba074e84',

            'debian:10'           => '',

            'debian:11'           => '76ff75fade399ac5cadfb4c225664f8bbe282c853880c1a1c7651f2dbb8a18b3347d99a6797b78cbef1b54a89d8b08f5b8026ac2e46ca8a1912a44b075c41c8c',
            'debian:aarch64:11'   => 'a957db77564b6e0bde80c8c97faff7d788d2fd2697be5b33b2239ae99d9d3a3c92fe8e82f704da0ca347b096db4120b39b6318419156749ffe5a5ac9185a0dfc',

            'debian:12' => '37315aaf8e1e91cf76116997e5f08c8ad02f2419e5812f7782f682109e1abca69d48045c787b18b3a4dd3c9f06a8f68cdd267e8c6ce4eeae7367eca85b2d239b',
            'debian:aarch64:12' => '03c0b86655c896b9f0b57d8ae0409a75e9bd90ed90d3849d2db1091398e114d18c2e3bf66d9b844680aae09ccc723c3025caf941775c1bac3c97b550193e9b55',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => 'a842f359786da92e05408fefa8ac3a21a06e405b016623fcf800840833495b6c1847659b424e77d8efd29c9ff2ed64c135ab68de345861d1e5992bd0bdcdc452',
            'ubuntu:aarch64:20.04'=> 'ce9581e9987f7521b90408c51e17fb0a814ca874d16b723456db95f52b324e18806663ce06c19f75c31d32460bd2378ac5a53274beb8a1008d35743e27a7ffbc',

            'ubuntu:22.04'        => '339e170a34d92c8b0ff032c5cf534e29c6f8fa3cdea70c5dd49da2fedc65a92fb1f3494947f992d1cf7d0dbd008b2066f4e1db53e91384510ccb78d457a9e5d0',
            'ubuntu:aarch64:22.04'=> '3965fcca69c58bb4d9fb17eb3836d30ddbf9bcc1d6fc3c4028d2870f74aaf5d1603967bf6c3758a661eff0db3e9e03aedea0a9b4e6345edf1d0ddd125e0e1720',
            'ubuntu:24.04' => '4a730237ed467e2e4d6035df8f1ea430b0a37bebbb0d344cb697e128cbcf7e594ec9734800cd3f039dbd8bda8850942a6d0340e3951c74e6e3caf860f6001a20',
            'ubuntu:aarch64:24.04'=> '149a2de0630444c0ce371ea8304288fb0dcadd5ef42d7958bd9ac58fbcd5d710cffd2a2ea97fb0d820fb3a83b58243aac0e28554ec177234136c15a7bd56f40b',
        },
        'gtest_1_13_0' => {
            'debian:10'           => '',

            'debian:11'           => '03643f027c23da835178d3e0e9232c423180d178ed224476b914b0a0e5250fdb8871455329e1fa59b8ea4a0de84b4fc5e466536aaaa75bc618e32cb345f363e4',
            'debian:aarch64:11'   => '24b24574dbbc638e5b395a2caa7284530de21ab35b2ba9081bdddc1b0dd1cf14d0819fe94e5503e5479b56bae146dc37ddc2646fcce993af50ba9b9be2a5c75a',

            'debian:12' => '62ac2e03afe83339d8f4f3f5aec491ca904a4f3a23f73a06f948e9406167360c51f40e6eedde30f7abcea105121509d53d01cb5da30c31018c4a1baaa0bc5b82',
            'debian:aarch64:12' => '19b4e30f92c675c3de8cf228f30bfeedbf1804c978c99b336bf91ac36d554f89dbe641e0a6729c7897d04bda135a63f333b5598d357ecb19827ea96129b0741c',

            'ubuntu:16.04'        => '',
            'ubuntu:18.04'        => '',

            'ubuntu:20.04'        => 'e21605eadf6d77b11f1b06ca4f763d24d9f50f52670a8d86684ed1f63cbf3c5f80e0e0402cba7bf5e5eb43e4975ac15b8f58d8fb3e57ddaf2c46f86eb4acb770',
            'ubuntu:aarch64:20.04'=> 'dd2ebee6b440c573805ca0887f9f84f69d3d61ed8f73114acd3143a0c638ca96ee741f5e9ee286770d2d52d70fa2c5e6c25adab450ad9b4c25a99bfd5c3967be',

            'ubuntu:22.04'        => '21cdc41e9458f2342401678d29c29176598f02d67adcc004502907068a944015d5789a41d72f8c3eb0e6e48010a421f31baf24b8d8e91db98c930c329eae12d6',
            'ubuntu:aarch64:22.04'=> '287165a558c2f1b95d31c3366fd4d8c8d1dfe5e75ec10c88e7895bbf357d0d47b389ccc1107689343c0b007f6832ddfab511bbcf9ed049036b462a9f8ea902d2',

            'centos:7'            => '',

            'centos:8'            => '0cd23ddb4274feb9b7d3ae54061a1c3a1a9c099e9601e2b4b475ac000628c07e1a8c21336306db4385cc776573ff00b05c3ecab87270a3f25b65aa4fe15c9142',
            'centos:aarch64:8'    => '40b42328801141dd06b1537f2f8703c7bfac12b664bdb5ab750d9c1a20f0fc2c1aea1e1b5333bccba01ed716ae085aec0acb97655a1739716eacbe5083cf26c9',

            'centos:9'            => '67afc18ed69c7a820de0aadf52e147b1dbaba48954a7fe0ad2a86581b938c731b04ca8e571a6ca93e6ca265b85acf2147a00ba4f970eb481a8bc3e345c10636c',
            'centos:aarch64:9'    => '07beaa90bca5acdc0d0d659deb978b201c201aa4a08107059c65ddcee5b177a71d9f76460f124cd2e45e3ad2d4187538ba80f29dc118bc25f0ee2030ec55ee69',
            'ubuntu:24.04' => 'b61e794c9e0ea55b0614ba5fac18eb9bc4257b5d808563d41a3b4b2914454f53f058f7a97ad2daca3dc3bc79ada0fc3b9dee42315c561ab90abb27db7b46a85c',
            'ubuntu:aarch64:24.04'=> '79b6db2fb0a3486e968733c8b75bcc05c703258945fc7403f9cd882c986067ed46b85ddce5e1cbaded71acaeebd84fd969c9ca0de312cf80b056182f9ebb27cb',
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

            'debian:11'           => 'ba7bc4c9a86cb3f079c7a203957d5abdf3bbf1a2fc3dd35e27ad6b35e7cbfa1e95fb987faf82f71455d3d3292106141db4861cef52b0425bf33fad27c7468820',
            'debian:aarch64:11'   => 'f954b2b12892cd8f7f4e2a50a09b5c44903db142ef47b31499e610ef4b2dfb09321922a5a66d5607d678a3a0b4d71b0c4e66b0c3d63e872ca89bd58505047fef',

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
