;;; Crate sources for rust-sysroot-riscv32imac-xous-elf dependencies
;;; Generated for betrusted-io/rust 1.90.0-xous branch

(define-module (xous-sysroot-crates)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system cargo)
  #:use-module ((guix licenses) #:prefix license:))

;; Helper to create crate source origins
(define (crate-source name version hash)
  (origin
    (method url-fetch)
    (uri (crate-uri name version))
    (file-name (string-append "rust-" name "-" version ".tar.gz"))
    (sha256 (base32 hash))))

(define-public rust-addr2line-0.25.0
  (crate-source "addr2line" "0.25.0"
                "0hqxvdi3d4n6ffz3bndm6aq9kvg36ga7wxnv3n8hql2jcsizrjws"))

(define-public rust-adler2-2.0.1
  (crate-source "adler2" "2.0.1"
                "1ymy18s9hs7ya1pjc9864l30wk8p2qfqdi7mhhcc5nfakxbij09j"))

(define-public rust-cc-1.2.0
  (crate-source "cc" "1.2.0"
                "1f3dndil5f864zhyc6f513xshs6b8mlxn0ipqww0awdxb0hr7sqs"))

(define-public rust-cfg-if-1.0.1
  (crate-source "cfg-if" "1.0.1"
                "0s0jr5j797q1vqjcd41l0v5izlmlqm7lxy512b418xz5r65mfmcm"))

(define-public rust-dlmalloc-0.2.10
  (crate-source "dlmalloc" "0.2.10"
                "0l9xy7nzlpqfx69ibjzvqyq7ys9516fgllp8vfsznsbvwnz2sfps"))

(define-public rust-fortanix-sgx-abi-0.6.1
  (crate-source "fortanix-sgx-abi" "0.6.1"
                "113gvr6azrpcixbbinl7scyzdpsrd3dd079pyja86gmqspnqbz2y"))

(define-public rust-getopts-0.2.23
  (crate-source "getopts" "0.2.23"
                "1ha8a3l3w68yrw3qjfzj0pak0rppf1yghign03iri1llxdisx9nb"))

(define-public rust-gimli-0.32.0
  (crate-source "gimli" "0.32.0"
                "1zlgga0cmfc4cpi68mmrmz6w4x9j3rpzimly9w809vy91ds3smlk"))

(define-public rust-hashbrown-0.15.4
  (crate-source "hashbrown" "0.15.4"
                "1mg045sm1nm00cwjm7ndi80hcmmv1v3z7gnapxyhd9qxc62sqwar"))

(define-public rust-hermit-abi-0.5.2
  (crate-source "hermit-abi" "0.5.2"
                "1744vaqkczpwncfy960j2hxrbjl1q01csm84jpd9dajbdr2yy3zw"))

(define-public rust-libc-0.2.174
  (crate-source "libc" "0.2.174"
                "0xl7pqvw7g2874dy3kjady2fjr4rhj5lxsnxkkhr5689jcr6jw8i"))

(define-public rust-memchr-2.7.5
  (crate-source "memchr" "2.7.5"
                "1h2bh2jajkizz04fh047lpid5wgw2cr9igpkdhl3ibzscpd858ij"))

(define-public rust-miniz-oxide-0.8.9
  (crate-source "miniz_oxide" "0.8.9"
                "05k3pdg8bjjzayq3rf0qhpirq9k37pxnasfn4arbs17phqn6m9qz"))

(define-public rust-object-0.37.1
  (crate-source "object" "0.37.1"
                "0jhvws8f1rq4mba5czpmj3jk11x41f4m1l5knil1g7h6c4qr9z83"))

(define-public rust-r-efi-5.3.0
  (crate-source "r-efi" "5.3.0"
                "03sbfm3g7myvzyylff6qaxk4z6fy76yv860yy66jiswc2m6b7kb9"))

(define-public rust-r-efi-alloc-2.1.0
  (crate-source "r-efi-alloc" "2.1.0"
                "0m338vaggbcc2x04lcf99kwkvk8vc0vqbanr8jf0zfx97kpmhbyw"))

(define-public rust-rand-0.9.2
  (crate-source "rand" "0.9.2"
                "1lah73ainvrgl7brcxx0pwhpnqa3sm3qaj672034jz8i0q7pgckd"))

(define-public rust-rand-core-0.9.3
  (crate-source "rand_core" "0.9.3"
                "0f3xhf16yks5ic6kmgxcpv1ngdhp48mmfy4ag82i1wnwh8ws3ncr"))

(define-public rust-rand-xorshift-0.4.0
  (crate-source "rand_xorshift" "0.4.0"
                "0njsn25pis742gb6b89cpq7jp48v9n23a9fvks10yczwks8n4fai"))

(define-public rust-rustc-demangle-0.1.25
  (crate-source "rustc-demangle" "0.1.25"
                "0kxq6m0drr40434ch32j31dkg00iaf4zxmqg7sqxajhcz0wng7lq"))

(define-public rust-rustc-literal-escaper-0.0.5
  (crate-source "rustc-literal-escaper" "0.0.5"
                "12s3w2mpgpjgzi6w19k6yr6vfcczkd6cv4vld514z9f5fzd2kvp4"))

(define-public rust-shlex-1.3.0
  (crate-source "shlex" "1.3.0"
                "0r1y6bv26c1scpxvhg2cabimrmwgbp4p3wy6syj9n0c4s3q2znhg"))

(define-public rust-unicode-width-0.2.1
  (crate-source "unicode-width" "0.2.1"
                "0k0mlq7xy1y1kq6cgv1r2rs2knn6rln3g3af50rhi0dkgp60f6ja"))

(define-public rust-unwinding-0.2.7
  (crate-source "unwinding" "0.2.7"
                "0lc7m3sh18g0bnhw3xidqlrlxf4rxgri8jhbm7ci7qpdpz1gd03x"))

(define-public rust-wasi-0.11.1
  (crate-source "wasi" "0.11.1+wasi-snapshot-preview1"
                "0jx49r7nbkbhyfrfyhz0bm4817yrnxgd3jiwwwfv0zl439jyrwyc"))

(define-public rust-windows-sys-0.59.0
  (crate-source "windows-sys" "0.59.0"
                "0fw5672ziw8b3zpmnbp9pdv1famk74f1l9fcbc3zsrzdg56vqf0y"))

(define-public rust-windows-targets-0.52.6
  (crate-source "windows-targets" "0.52.6"
                "0wwrx625nwlfp7k93r2rra568gad1mwd888h1jwnl0vfg5r4ywlv"))

(define-public rust-windows-aarch64-gnullvm-0.52.6
  (crate-source "windows_aarch64_gnullvm" "0.52.6"
                "1lrcq38cr2arvmz19v32qaggvj8bh1640mdm9c2fr877h0hn591j"))

(define-public rust-windows-aarch64-msvc-0.52.6
  (crate-source "windows_aarch64_msvc" "0.52.6"
                "0sfl0nysnz32yyfh773hpi49b1q700ah6y7sacmjbqjjn5xjmv09"))

(define-public rust-windows-i686-gnu-0.52.6
  (crate-source "windows_i686_gnu" "0.52.6"
                "02zspglbykh1jh9pi7gn8g1f97jh1rrccni9ivmrfbl0mgamm6wf"))

(define-public rust-windows-i686-gnullvm-0.52.6
  (crate-source "windows_i686_gnullvm" "0.52.6"
                "0rpdx1537mw6slcpqa0rm3qixmsb79nbhqy5fsm3q2q9ik9m5vhf"))

(define-public rust-windows-i686-msvc-0.52.6
  (crate-source "windows_i686_msvc" "0.52.6"
                "0rkcqmp4zzmfvrrrx01260q3xkpzi6fzi2x2pgdcdry50ny4h294"))

(define-public rust-windows-x86-64-gnu-0.52.6
  (crate-source "windows_x86_64_gnu" "0.52.6"
                "0y0sifqcb56a56mvn7xjgs8g43p33mfqkd8wj1yhrgxzma05qyhl"))

(define-public rust-windows-x86-64-gnullvm-0.52.6
  (crate-source "windows_x86_64_gnullvm" "0.52.6"
                "03gda7zjx1qh8k9nnlgb7m3w3s1xkysg55hkd1wjch8pqhyv5m94"))

(define-public rust-windows-x86-64-msvc-0.52.6
  (crate-source "windows_x86_64_msvc" "0.52.6"
                "1v7rb5cibyzx8vak29pdrk8nx9hycsjs4w0jgms08qk49jl6v7sq"))

;; Export list of all sysroot crates for use by xous-sysroot build
(define-public sysroot-crate-origins
  (list
   rust-addr2line-0.25.0
   rust-adler2-2.0.1
   rust-cc-1.2.0
   rust-cfg-if-1.0.1
   rust-dlmalloc-0.2.10
   rust-fortanix-sgx-abi-0.6.1
   rust-getopts-0.2.23
   rust-gimli-0.32.0
   rust-hashbrown-0.15.4
   rust-hermit-abi-0.5.2
   rust-libc-0.2.174
   rust-memchr-2.7.5
   rust-miniz-oxide-0.8.9
   rust-object-0.37.1
   rust-r-efi-5.3.0
   rust-r-efi-alloc-2.1.0
   rust-rand-0.9.2
   rust-rand-core-0.9.3
   rust-rand-xorshift-0.4.0
   rust-rustc-demangle-0.1.25
   rust-rustc-literal-escaper-0.0.5
   rust-shlex-1.3.0
   rust-unicode-width-0.2.1
   rust-unwinding-0.2.7
   rust-wasi-0.11.1
   rust-windows-sys-0.59.0
   rust-windows-targets-0.52.6
   rust-windows-aarch64-gnullvm-0.52.6
   rust-windows-aarch64-msvc-0.52.6
   rust-windows-i686-gnu-0.52.6
   rust-windows-i686-gnullvm-0.52.6
   rust-windows-i686-msvc-0.52.6
   rust-windows-x86-64-gnu-0.52.6
   rust-windows-x86-64-gnullvm-0.52.6
   rust-windows-x86-64-msvc-0.52.6))
