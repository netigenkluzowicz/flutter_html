import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_html/html_parser.dart';
import 'package:flutter_html/src/anchor.dart';
import 'package:flutter_html/src/html_elements.dart';
import 'package:flutter_html/src/navigation_delegate.dart';
import 'package:flutter_html/src/utils.dart';
import 'package:flutter_html/src/widgets/iframe_unsupported.dart'
  if (dart.library.io) 'package:flutter_html/src/widgets/iframe_unsupported.dart'
  if (dart.library.html) 'package:flutter_html/src/widgets/iframe_web.dart';
import 'package:flutter_html/style.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:html/dom.dart' as dom;

/// A [ReplacedElement] is a type of [StyledElement] that does not require its [children] to be rendered.
///
/// A [ReplacedElement] may use its children nodes to determine relevant information
/// (e.g. <video>'s <source> tags), but the children nodes will not be saved as [children].
abstract class ReplacedElement extends StyledElement {
  PlaceholderAlignment alignment;

  ReplacedElement({
    required String name,
    required Style style,
    required String elementId,
    List<StyledElement>? children,
    dom.Element? node,
    this.alignment = PlaceholderAlignment.aboveBaseline,
  }) : super(name: name, children: children ?? [], style: style, node: node, elementId: elementId);

  static List<String?> parseMediaSources(List<dom.Element> elements) {
    return elements
        .where((element) => element.localName == 'source')
        .map((element) {
      return element.attributes['src'];
    }).toList();
  }

  Widget? toWidget(RenderContext context);
}

/// [TextContentElement] is a [ContentElement] with plaintext as its content.
class TextContentElement extends ReplacedElement {
  String? text;
  dom.Node? node;

  TextContentElement({
    required Style style,
    required this.text,
    this.node,
    dom.Element? element,
  }) : super(name: "[text]", style: style, node: element, elementId: "[[No ID]]");

  @override
  String toString() {
    return "\"${text!.replaceAll("\n", "\\n")}\"";
  }

  @override
  Widget? toWidget(_) => null;
}

/// [ImageContentElement] is a [ReplacedElement] with an image as its content.
/// https://developer.mozilla.org/en-US/docs/Web/HTML/Element/img
class ImageContentElement extends ReplacedElement {
  final String? src;
  final String? alt;

  ImageContentElement({
    required String name,
    required this.src,
    required this.alt,
    required dom.Element node,
  }) : super(name: name, style: Style(), node: node, alignment: PlaceholderAlignment.middle, elementId: node.id);

  @override
  Widget toWidget(RenderContext context) {
    for (final entry in context.parser.imageRenders.entries) {
      if (entry.key.call(attributes, element)) {
        final widget = entry.value.call(context, attributes, element);
        return Builder(
          builder: (buildContext) {
            return GestureDetector(
              key: AnchorKey.of(context.parser.key, this),
              child: widget,
              onTap: () {
                if (MultipleTapGestureDetector.of(buildContext) != null) {
                  MultipleTapGestureDetector.of(buildContext)!.onTap?.call();
                }
                context.parser.onImageTap?.call(src, context, attributes, element);
              },
            );
          }
        );
      }
    }
    return SizedBox(width: 0, height: 0);
  }
}

/// AudioContentElement removed.
class CustomAudioContentElement extends ReplacedElement {
  final List<String?> src;

  CustomAudioContentElement({
    required String name,
    required this.src,
    required dom.Element node,
  }) : super(name: name, style: Style(), node: node, elementId: node.id);

  @override
  Widget toWidget(RenderContext context) {
    return Container();
  }
}

/// VideoContentElement removed.
class CustomVideoElement extends ReplacedElement {
  final List<String?> src;
  final double? width;
  final double? height;

  CustomVideoElement({
    required String name,
    required this.src,
    required this.width,
    required this.height,
    required dom.Element node,
  }) : super(name: name, style: Style(), node: node, elementId: node.id);

  @override
  Widget toWidget(RenderContext context) {
    return Container();
  }
}

/// [SvgContentElement] is a [ReplacedElement] with an SVG as its contents.
class SvgContentElement extends ReplacedElement {
  final String data;
  final double? width;
  final double? height;

  SvgContentElement({
    required String name,
    required this.data,
    required this.width,
    required this.height,
    required dom.Element node,
  }) : super(name: name, style: Style(), node: node, elementId: node.id, alignment: PlaceholderAlignment.middle);

  @override
  Widget toWidget(RenderContext context) {
    return SvgPicture.string(
      data,
      key: AnchorKey.of(context.parser.key, this),
      width: width,
      height: height,
    );
  }
}

class EmptyContentElement extends ReplacedElement {
  EmptyContentElement({String name = "empty"}) : super(name: name, style: Style(), elementId: "[[No ID]]");

  @override
  Widget? toWidget(_) => null;
}

class RubyElement extends ReplacedElement {
  dom.Element element;

  RubyElement({
    required this.element,
    required List<StyledElement> children,
    String name = "ruby"
  }) : super(name: name, alignment: PlaceholderAlignment.middle, style: Style(), elementId: element.id, children: children);

  @override
  Widget toWidget(RenderContext context) {
    String? textNode;
    List<Widget> widgets = <Widget>[];
    final rubySize = max(9.0, context.style.fontSize!.size! / 2);
    final rubyYPos = rubySize + rubySize / 2;
    context.tree.children.forEach((c) {
      if (c is TextContentElement) {
        textNode = c.text;
      }
      if (!(c is TextContentElement)) {
        if (c.name == "rt" && textNode != null) {
          final widget = Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                  alignment: Alignment.bottomCenter,
                  child: Center(
                      child: Transform(
                          transform:
                              Matrix4.translationValues(0, -(rubyYPos), 0),
                          child: ContainerSpan(
                            newContext: RenderContext(
                              buildContext: context.buildContext,
                              parser: context.parser,
                              style: c.style,
                              tree: c,
                            ),
                            style: c.style,
                            child: Text(c.element!.innerHtml,
                                style: c.style
                                    .generateTextStyle()
                                    .copyWith(fontSize: rubySize)),
                          )))),
              ContainerSpan(
                  newContext: context,
                  style: context.style,
                  child: Text(textNode!.trim(),
                      style: context.style.generateTextStyle())),
            ],
          );
          widgets.add(widget);
        }
      }
    });
    return Row(
      key: AnchorKey.of(context.parser.key, this),
      crossAxisAlignment: CrossAxisAlignment.end,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }
}

ReplacedElement parseReplacedElement(
  dom.Element element,
  List<StyledElement> children,
  NavigationDelegate? navigationDelegateForIframe,
) {
  switch (element.localName) {
    case "audio":
      final sources = <String?>[
        if (element.attributes['src'] != null) element.attributes['src'],
        ...ReplacedElement.parseMediaSources(element.children),
      ];
      if (sources.isEmpty || sources.first == null) {
        return EmptyContentElement();
      }
      return CustomAudioContentElement(
        name: "audio",
        src: sources,
        node: element,
      );
    case "br":
      return TextContentElement(
        text: "\n",
        style: Style(whiteSpace: WhiteSpace.PRE),
        element: element,
        node: element
      );
    case "iframe":
      return IframeContentElement(
          name: "iframe",
          src: element.attributes['src'],
          width: double.tryParse(element.attributes['width'] ?? ""),
          height: double.tryParse(element.attributes['height'] ?? ""),
          navigationDelegate: navigationDelegateForIframe,
          node: element,
      );
    case "img":
      return ImageContentElement(
        name: "img",
        src: element.attributes['src'],
        alt: element.attributes['alt'],
        node: element,
      );
    case "video":
      final sources = <String?>[
        if (element.attributes['src'] != null) element.attributes['src'],
        ...ReplacedElement.parseMediaSources(element.children),
      ];
      if (sources.isEmpty || sources.first == null) {
        return EmptyContentElement();
      }
      return CustomVideoElement(
        name: "video",
        src: sources,
        width: double.tryParse(element.attributes['width'] ?? ""),
        height: double.tryParse(element.attributes['height'] ?? ""),
        node: element,
      );
    case "svg":
      return SvgContentElement(
        name: "svg",
        data: element.outerHtml,
        width: double.tryParse(element.attributes['width'] ?? ""),
        height: double.tryParse(element.attributes['height'] ?? ""),
        node: element,
      );
    case "ruby":
      return RubyElement(
        element: element,
        children: children,
      );
    default:
      return EmptyContentElement(name: element.localName == null ? "[[No Name]]" : element.localName!);
  }
}
