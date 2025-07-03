import 'package:flutter/cupertino.dart';



class BlogPage extends StatelessWidget {
  const BlogPage({super.key});






  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(30),
      child: Column(
        children: [
          Row(),
          Row()
        ],
      )
    );
  }



}




class ImagesSection extends StatelessWidget {
  final List<String> imageUrls;


  const ImagesSection({super.key, required this.imageUrls});



  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(30),
      child: Column(
        children: [
          Row(
            children: [
              Image(image: ),
              Image(image: image),
              Image(image: image)
            ],
          ),
          Row(
            children: [
              Image(image: image),
              Image(image: image),
              Image(image: image)
            ],
          )
        ],
      )
    );
  }
}