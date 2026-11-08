/* Nova Informática BenchOS - apresentação durante a instalação */
import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation {
    id: presentation

    Timer {
        interval: 7000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Rectangle { anchors.fill: parent; color: "#05080f"; z: -1 }

    Slide { Image { source: "slide1.png"; anchors.fill: parent; fillMode: Image.PreserveAspectFit; smooth: true } }
    Slide { Image { source: "slide2.png"; anchors.fill: parent; fillMode: Image.PreserveAspectFit; smooth: true } }
    Slide { Image { source: "slide3.png"; anchors.fill: parent; fillMode: Image.PreserveAspectFit; smooth: true } }
    Slide { Image { source: "slide4.png"; anchors.fill: parent; fillMode: Image.PreserveAspectFit; smooth: true } }
    Slide { Image { source: "slide5.png"; anchors.fill: parent; fillMode: Image.PreserveAspectFit; smooth: true } }

    function onActivate() { presentation.currentSlide = 0; }
    function onLeave() { }
}
