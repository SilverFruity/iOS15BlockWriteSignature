//
//  ViewController.m
//  iOS15BlockWriteSignature
//
//  Created by Jiang on 2021/9/25.
//

#import "ViewController.h"
#import <WebKit/WebKit.h>
enum {
    BLOCK_DEALLOCATING =      (0x0001),
    BLOCK_REFCOUNT_MASK =     (0xfffe),
    BLOCK_CREATED_FROM_MFGO =    (1 << 23),
    BLOCK_NEEDS_FREE =        (1 << 24),
    BLOCK_HAS_COPY_DISPOSE =  (1 << 25),
    BLOCK_HAS_CTOR =          (1 << 26),
    BLOCK_IS_GC =             (1 << 27),
    BLOCK_IS_GLOBAL =         (1 << 28),
    BLOCK_USE_STRET =         (1 << 29),
    BLOCK_HAS_SIGNATURE  =    (1 << 30)
};

struct MFSimulateBlock {
    void *isa;
    int flags;
    int reserved;
    void *invoke;
    struct MFGOSimulateBlockDescriptor *descriptor;
    void *wrapper;
};

struct MFGOSimulateBlockDescriptor {
    //Block_descriptor_1
    struct {
        unsigned long int reserved;
        unsigned long int size;
    };
    
    //Block_descriptor_2
    struct {
        // requires BLOCK_HAS_COPY_DISPOSE
        void (*copy)(void *dst, const void *src);
        void (*dispose)(const void *);
    };
    
    //Block_descriptor_3
    struct {
        // requires BLOCK_HAS_SIGNATURE
        const char *signature;
    };
};

@interface ViewController ()<WKNavigationDelegate>
@property (nonatomic, strong)WKWebView *webView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    WKWebView *webView = [WKWebView new];
    [self.view addSubview:webView];
    webView.navigationDelegate = self;
    
    webView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [webView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [webView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [webView.leftAnchor constraintEqualToAnchor:self.view.leftAnchor],
        [webView.rightAnchor constraintEqualToAnchor:self.view.rightAnchor],
    ]];
    [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.baidu.com"]]];
}
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler{
    
    id block = decisionHandler;
    struct MFSimulateBlock *blockRef = (__bridge struct MFSimulateBlock *)block;
    // ---- 2021.9.24 TODO:
    // 针对 WKWebView 的 navigationDelegate 的 block:
    // decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
    // ios 15 下直接写入 signatureLocation 内存会导致 EXC_BAD_ACCESS 错误，同时此 block 是一个堆 block，使用内存地址直接写入按理说应该是没有问题。不知是对此内存做了内存保护🤔？可是当在调试的时候，使用 lldb 调试器写入该地址，却完全没有问题。
    // 目前为了规避崩溃问题，既然不能操作 signature 的地址内存，那就直接覆盖 descriptor 的内存
    // ⚠️ 此处存在的问题为：使用 malloc 开辟的内存空间，存在内存泄漏的问题。
    
//    struct MFGOSimulateBlockDescriptor *des = malloc(sizeof(struct MFGOSimulateBlockDescriptor));
//    memcpy(des, blockRef->descriptor, sizeof(struct MFGOSimulateBlockDescriptor));
//    blockRef->descriptor = des;
    
    // ----
    
    void *signatureLocation = blockRef->descriptor;
    signatureLocation += sizeof(unsigned long int);
    signatureLocation += sizeof(unsigned long int);
    int flags = blockRef->flags;
    if (flags & BLOCK_HAS_COPY_DISPOSE) {
        signatureLocation += sizeof(void(*)(void *dst, void *src));
        signatureLocation += sizeof(void (*)(void *src));
    }
    char *copied = strdup("v@?q");
    *(char **)signatureLocation = copied;
    blockRef->flags |= BLOCK_HAS_SIGNATURE;
    
    decisionHandler(WKNavigationActionPolicyAllow);
}


@end
