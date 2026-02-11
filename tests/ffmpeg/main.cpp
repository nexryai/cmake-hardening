#include <iostream>

extern "C" {
#include <libavutil/avutil.h>
}

int main() {
    std::cout << "FFmpeg Version: " << av_version_info() << std::endl;
    return 0;
}
