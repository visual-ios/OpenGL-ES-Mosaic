//
//  ViewController.m
//  滤镜
//
//  Created by 秦菥 on 2021/9/26.
//

#import "ViewController.h"
#import <OpenGLES/ES2/gl.h>

@interface ViewController ()

//上下文
@property (nonatomic, strong) EAGLContext *context;

@property (nonatomic, strong) CAEAGLLayer *myLayer;

@property (nonatomic, assign) GLuint program;

@property (nonatomic, assign) GLuint vertexBuffer;

@property (nonatomic, assign) GLuint textureID;

@property (nonatomic, copy) NSArray *shaderArray;
@property (nonatomic, copy) NSArray *titleArray;
@property (nonatomic, strong) UISegmentedControl *segmenControl;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    
    self.shaderArray = @[@"Normal", @"Gray",@"Mosaic",@"HexagonMosaic",@"TriangularMosaic"];
    self.titleArray = @[@"默认", @"灰度",@"默认马赛克",@"六边形马赛克",@"三角形马赛克"];
    
    [self filterInit];
    
    UISegmentedControl *segmentControl = [[UISegmentedControl alloc] initWithItems:self.titleArray];
    self.segmenControl = segmentControl;
    segmentControl.backgroundColor = [UIColor whiteColor];
    segmentControl.frame = CGRectMake(0, [UIApplication sharedApplication].statusBarFrame.size.height + 44, [UIScreen mainScreen].bounds.size.width, 50);
    [segmentControl addTarget:self action:@selector(segmentDidChange) forControlEvents:UIControlEventValueChanged];
    segmentControl.selectedSegmentIndex = 0;
    [self.view addSubview:segmentControl];
    
}

- (void)filterInit
{
    glClear(GL_COLOR_BUFFER_BIT);
    glClearColor(1, 1, 1, 1);
    //创建上下文
    [self createContext];
    //创建显示的CAEAGLayer
    [self createLayer];
    //创建缓存区
    [self createBuffer];
    glViewport(0, 0, self.drawableWidth, self.drawableHeight);
    
    //获取纹理图片
    UIImage *image = [UIImage imageNamed:@"kunkun"];
    self.textureID = [self createTextureWithImage:image];
    
    //创建顶点
    [self createVertices];
    
    [self segmentDidChange];
}

- (void)createContext
{
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:self.context];
}

- (void)createLayer
{
    CAEAGLLayer *layer = [[CAEAGLLayer alloc] init];
    self.myLayer = layer;
    layer.frame = CGRectMake(0, (self.view.frame.size.height - self.view.frame.size.width) / 2, self.view.frame.size.width, self.view.frame.size.width);
    [self.view.layer addSublayer:layer];
}

- (void)createBuffer
{
    GLuint renderBuffer;
    GLuint frameBuffer;
    glGenRenderbuffers(1, &renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.myLayer];
    
    glGenFramebuffers(1, &frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderBuffer);
}

- (GLuint)createTextureWithImage:(UIImage *)image
{
    CGImageRef cgImageRef = [image CGImage];
    if (!cgImageRef) {
        NSLog(@"Failed to load image");
        exit(1);
    }
    //读取图片的大小宽高
    GLuint width = (GLuint)CGImageGetWidth(cgImageRef);
    GLuint height = (GLuint)CGImageGetHeight(cgImageRef);
    //获取图片的rect
    CGRect rect = CGRectMake(0, 0, width, height);
    
    //获取图片的颜色空间
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    //3.获取图片字节数 宽*高*4（RGBA）
    void *imageData = malloc(width * height * 4);
    //4.创建上下文
    /*
     参数1：data,指向要渲染的绘制图像的内存地址
     参数2：width,bitmap的宽度，单位为像素
     参数3：height,bitmap的高度，单位为像素
     参数4：bitPerComponent,内存中像素的每个组件的位数，比如32位RGBA，就设置为8
     参数5：bytesPerRow,bitmap的没一行的内存所占的比特数
     参数6：colorSpace,bitmap上使用的颜色空间  kCGImageAlphaPremultipliedLast：RGBA
     */
    CGContextRef context = CGBitmapContextCreate(imageData, width, height, 8, width * 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    
    //将图片翻转过来(图片默认是倒置的)
//    CGContextTranslateCTM(context, 0, height);
//    CGContextScaleCTM(context, 1.0f, -1.0f);
//    CGColorSpaceRelease(colorSpace);
//    CGContextClearRect(context, rect);
    
    //对图片进行重新绘制，得到一张新的解压缩后的位图
    CGContextDrawImage(context, rect, cgImageRef);
    
    GLuint textureID;
    glGenTextures(1, &textureID);
    glBindTexture(GL_TEXTURE_2D, textureID);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
    
    //设置纹理属性
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    //绑定纹理
    glBindTexture(GL_TEXTURE_2D, 0);
    
    CGContextRelease(context);
    free(imageData);
    
    return textureID;
}

- (void)createVertices
{
    GLfloat vertex[] =
    {
        1.f, -1.f, 0.f,     1.0f, 1.0f,
        -1.f, 1.f, 0.f,     0.0f, 0.0f,
        -1.f, -1.f, 0.f,    0.0f, 1.0f,
        
        1.f, 1.f, 0.f,      1.0f, 0.0f,
        -1.f, 1.f, 0.f,     0.0f, 0.0f,
        1.f, -1.f, 0.f,     1.0f, 1.0f,
    };
    
    GLuint vertexBuffer;
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertex), vertex, GL_DYNAMIC_DRAW);
    self.vertexBuffer = vertexBuffer;
}


- (void)segmentDidChange
{
    [self setupShaderProgramWithName:self.shaderArray[self.segmenControl.selectedSegmentIndex]];
    
    
    
    glUseProgram(self.program);
    glBindBuffer(GL_ARRAY_BUFFER, self.vertexBuffer);
    glClear(GL_COLOR_BUFFER_BIT);
    glClearColor(1, 1, 1, 1);
    glDrawArrays(GL_TRIANGLES, 0, 6);
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)setupShaderProgramWithName:(NSString *)name
{
    GLuint program = [self programWithShaderName:name];
    //3. 获取Position,Texture,TextureCoords 的索引位置
    GLuint positionSlot = glGetAttribLocation(program, "Position");
    GLuint textureSlot = glGetUniformLocation(program, "Texture");
    GLuint textureCoordsSlot = glGetAttribLocation(program, "TextureCoords");
    
    //激活纹理
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.textureID);
    
    glUniform1i(textureSlot, 0);
    
    glEnableVertexAttribArray(positionSlot);
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, (float*)NULL);
    
    glEnableVertexAttribArray(textureCoordsSlot);
    glVertexAttribPointer(textureCoordsSlot, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, (float*)NULL + 3);
    
}

- (GLuint)programWithShaderName:(NSString *)name
{
    GLuint vertexShader = [self compileShaderWithName:name type:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShaderWithName:name type:GL_FRAGMENT_SHADER];
    
    GLuint program = glCreateProgram();
    self.program = program;
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    
    glLinkProgram(program);
    
    GLint linkSuccess;
    glGetProgramiv(program, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(program, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSAssert(NO, @"program链接失败：%@", messageString);
        exit(1);
    }
    //5.返回program
    return program;
}

- (GLuint)compileShaderWithName:(NSString *)name type:(GLenum)shaderType
{
    NSString *shaderPath = [[NSBundle mainBundle] pathForResource:name ofType:shaderType == GL_VERTEX_SHADER ? @"vsh" : @"fsh"];
    NSError *error;
    NSString *shaderString = [NSString stringWithContentsOfFile:shaderPath encoding:NSUTF8StringEncoding error:&error];
    if (!shaderString) {
        NSAssert(NO, @"读取shader失败");
        exit(1);
    }
    
    //2. 创建shader->根据shaderType
    GLuint shader = glCreateShader(shaderType);
    
    //3.获取shader source
    const char *shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength = (int)[shaderString length];
    glShaderSource(shader, 1, &shaderStringUTF8, &shaderStringLength);
    
    //4.编译shader
    glCompileShader(shader);
    
    //5.查看编译是否成功
    GLint compileSuccess;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shader, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSAssert(NO, @"shader编译失败：%@", messageString);
        exit(1);
    }
    //6.返回shader
    return shader;
}

//获取渲染缓存区的宽
- (GLint)drawableWidth {
    GLint backingWidth;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    return backingWidth;
}
//获取渲染缓存区的高
- (GLint)drawableHeight {
    GLint backingHeight;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    return backingHeight;
}

@end
