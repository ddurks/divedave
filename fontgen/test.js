const generator = require('@rtpa/phaser-bitmapfont-generator');

(async ()=>{

    //generate textures
    await generator.TextStyle2BitmapFont({
        path: './mydir',
        fileName: 'red-arial',
        textStyle: {
            fontFamily: 'Arial',
            fontSize: '20px',
            color: 'red',
        }
    });

    //generate textures
    await generator.TextStyle2BitmapFont({
        path: './mydir',
        fileName: 'green-arial',
        textStyle: {
            fontFamily: 'Arial',
            fontSize: '20px',
            color: 'green',
        }
    });

            //generate textures
    await generator.TextStyle2BitmapFont({
        path: './mydir',
        fileName: 'yellow-arial',
        textStyle: {
            fontFamily: 'Arial',
            fontSize: '20px',
            color: 'yellow',
        }
    });

    //exit node
    return process.exit(1);

})();
